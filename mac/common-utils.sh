#!/bin/bash

# shellcheck source=/dev/null
source "$(dirname "$0")/device-machine-allocation.sh"

# # ===== Global Variables =====
WORKSPACE_DIR="$HOME/.browserstack"
PROJECT_FOLDER="NOW"

# URL handling
DEFAULT_TEST_URL="https://bstackdemo.com"

# ===== Log files (per-run) =====
LOG_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/logs"
NOW_RUN_LOG_FILE=""

# ===== Global Variables =====
CX_TEST_URL="$DEFAULT_TEST_URL"

WEB_PLAN_FETCHED=false
MOBILE_PLAN_FETCHED=false
TEAM_PARALLELS_MAX_ALLOWED_WEB=0
TEAM_PARALLELS_MAX_ALLOWED_MOBILE=0

# App specific globals
APP_PLATFORM=""   # ios | android | all


# ===== Logging Functions =====
log_msg_to() {
    local message="$1"
    local dest_file=$NOW_RUN_LOG_FILE
    local ts
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    local line="[$ts] $message"
    
    # print to console
    if [[ "$RUN_MODE" == *"--debug"* ]]; then
        echo "$line"
    fi
    
    # write to dest file if provided
    if [ -n "$dest_file" ]; then
        mkdir -p "$(dirname "$dest_file")"
        echo "$line" >> "$NOW_RUN_LOG_FILE"
    fi
}

# Spinner function for long-running processes
show_spinner() {
    local pid=$1
    # shellcheck disable=SC1003
    local spin='|/-\'
    local i=0
    local ts
    ts="$(date +"%Y-%m-%d %H:%M:%S")"
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r⏳ Processing... %s" "${spin:$i:1}"
        sleep 0.1
    done
    echo ""
    log_info "Run Test command completed."
    sleep 5
    #log_msg_to "✅ Done!"
}

# ===== Workspace Management =====
setup_workspace() {
    log_section "⚙️ Environment & Credentials"
    local full_path="$WORKSPACE_DIR/$PROJECT_FOLDER"
    if [ ! -d "$full_path" ]; then
        mkdir -p "$full_path"
        log_info "Created onboarding workspace: $full_path"
    else
        log_success "Onboarding workspace found at: $full_path"
    fi
}


# ===== App Upload Management =====
handle_app_upload() {
    local app_platform=""
    if [[ "$RUN_MODE" == *"--silent"* || "$RUN_MODE" == *"--debug"* ]]; then
        upload_sample_app
        app_platform="android"
        export APP_PLATFORM="$app_platform"
        log_msg_to "Exported APP_PLATFORM=$APP_PLATFORM"
    else
        local choice
        choice=$(osascript -e '
            display dialog "How would you like to select your app?" ¬
            with title "BrowserStack App Upload" ¬
            with icon note ¬
            buttons {"Use Sample App", "Upload my App (.apk/.ipa)", "Cancel"} ¬
            default button "Upload my App (.apk/.ipa)"
        ' 2>/dev/null)
        
        if [[ "$choice" == *"Use Sample App"* ]]; then
            upload_sample_app
            app_platform="android"
            export APP_PLATFORM="$app_platform"
            log_msg_to "Exported APP_PLATFORM=$APP_PLATFORM"
            elif [[ "$choice" == *"Upload my App"* ]]; then
            upload_custom_app
        else
            return 1
        fi
    fi
}

upload_sample_app() {
    log_msg_to "⬆️ Uploading sample app to BrowserStack..."
    local upload_response
    upload_response=$(curl -s -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
        -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
    -F "url=https://www.browserstack.com/app-automate/sample-apps/android/WikipediaSample.apk")
    
    app_url=$(echo "$upload_response" | grep -o '"app_url":"[^"]*' | cut -d'"' -f4)
    export BROWSERSTACK_APP=$app_url
    log_msg_to "Exported BROWSERSTACK_APP=$BROWSERSTACK_APP"
    
    if [ -z "$app_url" ]; then
        log_msg_to "❌ Upload failed. Response: $upload_response"
        return 1
    fi
    
    log_msg_to "✅ App uploaded successfully: $app_url"
    return 0
}

upload_custom_app() {
    local app_platform=""
    local file_path
    file_path=$(osascript -e 'choose file with prompt "Select your .apk or .ipa file:" of type {"apk", "ipa"}' 2>/dev/null)
    
    if [ -z "$file_path" ]; then
        log_msg_to "❌ No file selected"
        return 1
    fi
    
    # Determine platform from file extension
    if [[ "$file_path" == *.ipa ]]; then
        app_platform="ios"
        elif [[ "$file_path" == *.apk ]]; then
        app_platform="android"
    else
        log_msg_to "❌ Invalid file type. Must be .apk or .ipa"
        return 1
    fi
    
    log_msg_to "⬆️ Uploading app to BrowserStack..."
    local upload_response
    upload_response=$(curl -s -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
        -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
    -F "file=@$file_path")
    
    local app_url
    app_url=$(echo "$upload_response" | grep -o '"app_url":"[^"]*' | cut -d'"' -f4)
    if [ -z "$app_url" ]; then
        log_msg_to "❌ Failed to upload app"
        return 1
    fi
    
    export BROWSERSTACK_APP=$app_url
    log_msg_to "✅ App uploaded successfully"
    log_msg_to "Exported BROWSERSTACK_APP=$BROWSERSTACK_APP"
    
    export APP_PLATFORM="$app_platform"
    log_msg_to "Exported APP_PLATFORM=$APP_PLATFORM"
    return 0
}

# ===== Dynamic config generators =====
generate_web_platforms() {
    local max_total_parallels=$1
    local platformsListContentFormat=$2
    local platform="web"
    local platformsList=""
    export NOW_PLATFORM="$platform"
    platformsList=$(pick_terminal_devices "$NOW_PLATFORM" "$max_total_parallels" "$platformsListContentFormat")
    echo "$platformsList"
}

generate_mobile_platforms() {
    local max_total_parallels=$1
    local platformsListContentFormat=$2
    local app_platform="$APP_PLATFORM"
    local platformsList=""
    platformsList=$(pick_terminal_devices "$app_platform" "$max_total_parallels", "$platformsListContentFormat")
    echo "$platformsList"
}


# ===== Fetch plan details (writes to GLOBAL) =====
fetch_plan_details() {
    local test_type=$1
    
    log_section "☁️ Account & Plan Details"
    log_info "Fetching BrowserStack plan for $test_type"
    local web_unauthorized=false
    local mobile_unauthorized=false
    
    if [[ "$test_type" == "web" || "$test_type" == "both" ]]; then
        RESPONSE_WEB=$(curl -s -w "\n%{http_code}" -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" https://api.browserstack.com/automate/plan.json)
        HTTP_CODE_WEB=$(echo "$RESPONSE_WEB" | tail -n1)
        RESPONSE_WEB_BODY=$(echo "$RESPONSE_WEB" | sed '$d')
        if [ "$HTTP_CODE_WEB" == "200" ]; then
            WEB_PLAN_FETCHED=true
            TEAM_PARALLELS_MAX_ALLOWED_WEB=$(echo "$RESPONSE_WEB_BODY" | grep -o '"parallel_sessions_max_allowed":[0-9]*' | grep -o '[0-9]*')
            export TEAM_PARALLELS_MAX_ALLOWED_WEB="$TEAM_PARALLELS_MAX_ALLOWED_WEB"
            log_msg_to "✅ Web Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_WEB"
        else
            log_msg_to "❌ Web Testing Plan fetch failed ($HTTP_CODE_WEB)"
            [ "$HTTP_CODE_WEB" == "401" ] && web_unauthorized=true
        fi
    fi
    
    if [[ "$test_type" == "app" || "$test_type" == "both" ]]; then
        RESPONSE_MOBILE=$(curl -s -w "\n%{http_code}" -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" https://api-cloud.browserstack.com/app-automate/plan.json)
        HTTP_CODE_MOBILE=$(echo "$RESPONSE_MOBILE" | tail -n1)
        RESPONSE_MOBILE_BODY=$(echo "$RESPONSE_MOBILE" | sed '$d')
        if [ "$HTTP_CODE_MOBILE" == "200" ]; then
            MOBILE_PLAN_FETCHED=true
            TEAM_PARALLELS_MAX_ALLOWED_MOBILE=$(echo "$RESPONSE_MOBILE_BODY" | grep -o '"parallel_sessions_max_allowed":[0-9]*' | grep -o '[0-9]*')
            export TEAM_PARALLELS_MAX_ALLOWED_MOBILE="$TEAM_PARALLELS_MAX_ALLOWED_MOBILE"
            log_msg_to "✅ Mobile App Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE"
        else
            log_msg_to "❌ Mobile App Testing Plan fetch failed ($HTTP_CODE_MOBILE)"
            [ "$HTTP_CODE_MOBILE" == "401" ] && mobile_unauthorized=true
        fi
    fi
    
    log_info "Plan summary: Web $WEB_PLAN_FETCHED ($TEAM_PARALLELS_MAX_ALLOWED_WEB max), Mobile $MOBILE_PLAN_FETCHED ($TEAM_PARALLELS_MAX_ALLOWED_MOBILE max)"
    
    if [[ "$test_type" == "web" && "$web_unauthorized" == true ]] || \
    [[ "$test_type" == "app" && "$mobile_unauthorized" == true ]] || \
    [[ "$test_type" == "both" && "$web_unauthorized" == true && "$mobile_unauthorized" == true ]]; then
        log_msg_to "❌ Unauthorized to fetch required plan(s). Exiting."
        exit 1
    fi
}

# Function to check if IP is private
is_private_ip() {
    case $1 in
        10.* | 192.168.* | 172.16.* | 172.17.* | 172.18.* | 172.19.* | \
        172.20.* | 172.21.* | 172.22.* | 172.23.* | 172.24.* | 172.25.* | \
        172.26.* | 172.27.* | 172.28.* | 172.29.* | 172.30.* | 172.31.* | "")
        return 0 ;;  # Private
        *)
        return 1 ;;  # Public
    esac
}

is_domain_private() {
    domain=${CX_TEST_URL#*://}  # remove protocol
    domain=${domain%%/*}  # remove everything after first "/"
    log_msg_to "Website domain: $domain"
    export NOW_WEB_DOMAIN="$CX_TEST_URL"
    export CX_TEST_URL="$CX_TEST_URL"
    
    # Resolve domain using Cloudflare DNS
    IP_ADDRESS=$(dig +short "$domain" @1.1.1.1 | head -n1)
    
    # Determine if domain is private
    if is_private_ip "$IP_ADDRESS"; then
        is_cx_domain_private=0
    else
        is_cx_domain_private=-1
    fi
    
    log_msg_to "Resolved IPs: $IP_ADDRESS"
    
    return $is_cx_domain_private
}


identify_run_status_java() {
    local log_file=$1
    local line=""
    # Extract the test summary line
    line=$(grep -m 2 -E "[INFO|ERROR].*Tests run" < "$log_file")
    # If not found, fail
    if [[ -z "$line" ]]; then
        log_warn "❌ No test summary line found."
        return 1
    fi
    
    # Extract numbers using regex
    tests_run=$(echo "$line" | grep -m 1 -oE "Tests run: [0-9]+" | awk '{print $3}')
    failures=$(echo "$line" | grep -m 1 -oE "Failures: [0-9]+" | awk '{print $2}')
    errors=$(echo "$line" | grep -m 1 -oE "Errors: [0-9]+" | awk '{print $2}')
    skipped=$(echo "$line" | grep -m 1 -oE "Skipped: [0-9]+" | awk '{print $2}')
    
    # Calculate passed tests
    passed=$(( tests_run-(failures+errors+skipped) ))
    
    # Check condition
    if (( passed > 0 )); then
        log_success "Success: $passed test(s) passed."
        return 0
    else
        log_error "Error: No tests passed (Tests run: $tests_run, Failures: $failures, Errors: $errors, Skipped: $skipped)"
        return 1
    fi
}


identify_run_status_nodejs() {
    
    local log_file=$1
    log_info "Identifying run status"
    local line=""
    line=$(grep -m 1 -E "Spec Files:.*passed.*total" < "$log_file")
    # If not found, fail
    if [[ -z "$line" ]]; then
        log_warn "❌ No test summary line found."
        return 1
    fi
    
    # Extract numbers using regex
    passed=$(echo "$line" | grep -oE '[0-9]+ passed' | awk '{print $1}')
    # Check condition
    if (( passed > 0 )); then
        log_success "Success: $passed test(s) passed"
        return 0
    else
        log_error "❌ Error: No tests passed"
        return 1
    fi
}


identify_run_status_python() {
    
    local log_file=$1
    log_info "Identifying run status"
    
    # Extract numbers and sum them
    passed_sum=$(grep -oE '[0-9]+ passed' "$log_file" | awk '{sum += $1} END {print sum+0}')
    
    echo "✅ Total Passed:  $passed_sum"
    
    # If not found, fail
    if [[ -z "$passed_sum" ]]; then
        log_warn "❌ No test summary line found."
        return 1
    fi
    
    # Check condition
    if (( passed_sum > 0 )); then
        log_success "Success: $passed_sum test(s) completed"
        return 0
    else
        log_error "❌ Error: No tests completed"
        return 1
    fi
}

clear_old_logs() {
    mkdir -p "$LOG_DIR"
    : > "$NOW_RUN_LOG_FILE"
    
    log_success "Logs cleared and fresh run initiated."
}


detect_os() {
    local unameOut=""
    unameOut="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    local response=""
    case "$unameOut" in
        linux*)
            # Detect WSL vs normal Linux
            if grep -qi "microsoft" /proc/version 2>/dev/null; then
                response="wsl"
            else
                response="linux"
            fi
            ;;
        darwin*)
            response="macos"
            ;;
        msys*|mingw*|cygwin*)
            response="windows"
            ;;
        *)
            response="unknown"
            ;;
    esac
    
    export NOW_OS=$response
}

