#!/bin/bash

# ===== Credential Management =====
get_browserstack_credentials() {
    local run_mode=$1
    local username=""
    local access_key=""
    if [[ "$RUN_MODE" == *"--silent"* || "$RUN_MODE" == *"--debug"* ]]; then
        username="$BROWSERSTACK_USERNAME"
        access_key="$BROWSERSTACK_ACCESS_KEY"
        log_info "BrowserStack credentials loaded from environment variables for user: $username" 
    else
    if [[ "$NOW_OS" == "macos" ]]; then
        username=$(osascript -e 'Tell application "System Events" to display dialog "Please enter your BrowserStack Username.\n\nNote: Locate it in your BrowserStack account profile page.\nhttps://www.browserstack.com/accounts/profile/details" default answer "" with title "BrowserStack Setup" buttons {"OK"} default button "OK"' \
        -e 'text returned of result')
    else
        echo "Please enter your BrowserStack Username."
        echo "Note: Locate it in your BrowserStack account profile page: https://www.browserstack.com/accounts/profile/details"
        read -r username
    fi
        
        if [ -z "$username" ]; then
            log_msg_to "❌ Username empty" 
            return 1
        fi
        
    if [[ "$NOW_OS" == "macos" ]]; then
        access_key=$(osascript -e 'Tell application "System Events" to display dialog "Please enter your BrowserStack Access Key.\n\nNote: Locate it in your BrowserStack account page.\nhttps://www.browserstack.com/accounts/profile/details" default answer "" with hidden answer with title "BrowserStack Setup" buttons {"OK"} default button "OK"' \
        -e 'text returned of result')
    else
        echo "Please enter your BrowserStack Access Key."
        echo "Note: Locate it in your BrowserStack account page: https://www.browserstack.com/accounts/profile/details"
        read -rs access_key
        echo "" # Newline after secret input
    fi
        if [ -z "$access_key" ]; then
            log_msg_to "❌ Access Key empty" 
            return 1
        fi
        
        export BROWSERSTACK_USERNAME=$username
        export BROWSERSTACK_ACCESS_KEY=$access_key
        log_info "BrowserStack credentials captured from user: $username"
    fi
    
    return 0
}

# ===== Tech Stack Management =====
get_tech_stack() {
    local run_mode=$1
    local tech_stack=""
    if [[ "$run_mode" == *"--silent"* || "$run_mode" == *"--debug"* ]]; then
        tech_stack="$TSTACK"
        log_msg_to "✅ Selected Tech Stack from environment: $tech_stack" 
    else
    if [[ "$NOW_OS" == "macos" ]]; then
        tech_stack=$(osascript -e 'Tell application "System Events" to display dialog "Select installed tech stack:" buttons {"java", "python", "nodejs"} default button "java" with title "Testing Framework Technology Stack"' \
        -e 'button returned of result')
    else
        echo "Select installed tech stack:"
        select opt in "java" "python" "nodejs"; do
            case $opt in
                "java"|"python"|"nodejs") tech_stack=$opt; break ;;
                *) echo "Invalid option";;
            esac
        done
    fi
    fi
    log_msg_to "✅ Selected Tech Stack: $tech_stack" 
    log_info "Tech Stack: $tech_stack"
    
    export TECH_STACK="$tech_stack"
    log_msg_to "Exported TECH_STACK=$TECH_STACK" 
}


# ===== URL Management =====
get_test_url() {
    local test_url=$DEFAULT_TEST_URL
    
    if [[ "$NOW_OS" == "macos" ]]; then
        test_url=$(osascript -e 'Tell application "System Events" to display dialog "Enter the URL you want to test with BrowserStack:\n(Leave blank for default: '"$DEFAULT_TEST_URL"')" default answer "" with title "Test URL Setup" buttons {"OK"} default button "OK"' \
        -e 'text returned of result')
    else
        echo "Enter the URL you want to test with BrowserStack:"
        echo "(Leave blank for default: $DEFAULT_TEST_URL)"
        read -r test_url
    fi
    
    if [ -n "$test_url" ]; then
        log_msg_to "🌐 Using custom test URL: $test_url" 
        log_info "🌐 Using custom test URL: $test_url" 
    else
        test_url="$DEFAULT_TEST_URL"
        log_msg_to "⚠️ No URL entered. Falling back to default: $test_url" 
        log_info "No URL entered. Falling back to default: $test_url" 
    fi
    
    export CX_TEST_URL="$test_url"
    log_msg_to "Exported TEST_URL $CX_TEST_URL" 
}


get_test_type() {
    local test_type=""
    if [[ "$RUN_MODE" == *"--silent"* || "$RUN_MODE" == *"--debug"* ]]; then
        test_type=$TT
        log_msg_to "✅ Selected Testing Type from environment: $TEST_TYPE" 
    else
    if [[ "$NOW_OS" == "macos" ]]; then
        test_type=$(osascript -e 'Tell application "System Events" to display dialog "Select testing type:" buttons {"web", "app"} default button "web" with title "Testing Type"' \
        -e 'button returned of result')
    else
        echo "Select testing type:"
        select opt in "web" "app"; do
            case $opt in
                "web"|"app") test_type=$opt; break ;;
                *) echo "Invalid option";;
            esac
        done
    fi
        log_msg_to "✅ Selected Testing Type: $TEST_TYPE" 
        RUN_MODE=$test_type
        log_info "Run Mode: ${RUN_MODE:-default}"
    fi
    export TEST_TYPE="$test_type"
    log_msg_to "Exported TEST_TYPE=$TEST_TYPE" 
}

perform_next_steps_based_on_test_type() {
    local test_type=$1
    case "$test_type" in
        "web")
            get_test_url
        ;;
        "app")
            get_upload_app
        ;;
        "both")
            get_test_url
            get_upload_app
        ;;
    esac
}

get_upload_app() {
    log_msg_to "Determining app upload steps." 
    handle_app_upload
}