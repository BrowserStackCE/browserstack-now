#!/usr/bin/env bash
# shellcheck shell=bash

setup_environment() {
    local setup_type=$1
    local tech_stack=$2
    local max_parallels
    
    log_section "📦 Project Setup"
    
    # Set variables based on setup type
    if [ "$setup_type" = "web" ]; then
        log_msg_to "Team max parallels for web: $TEAM_PARALLELS_MAX_ALLOWED_WEB" "$NOW_RUN_LOG_FILE"
        max_parallels=$TEAM_PARALLELS_MAX_ALLOWED_WEB
    else
        log_msg_to "Team max parallels for mobile: $TEAM_PARALLELS_MAX_ALLOWED_MOBILE" "$NOW_RUN_LOG_FILE"
        max_parallels=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    fi
    
    log_msg_to "Starting ${setup_type} setup for " "$tech_stack" "$NOW_RUN_LOG_FILE"
    
    local local_flag=false
    
    # Calculate parallels
    local total_parallels
    total_parallels=$(awk -v n="$max_parallels" 'BEGIN { printf "%d", n }')
    [ -z "$total_parallels" ] && total_parallels=1
    local parallels_per_platform=$total_parallels
    
    log_msg_to "[${setup_type} Setup]" "$NOW_RUN_LOG_FILE"
    log_msg_to "Total parallels allocated: $total_parallels" "$NOW_RUN_LOG_FILE"
    
    
    case "$tech_stack" in
        java)
            "setup_${setup_type}_java" "$local_flag" "$parallels_per_platform" "$NOW_RUN_LOG_FILE"
            log_section "✅ Results"
            identify_run_status_java "$NOW_RUN_LOG_FILE"
            check_return_value $? "$NOW_RUN_LOG_FILE" "${setup_type} setup succeeded." "❌ ${setup_type} setup failed. Check $log_file for details"
        ;;
        python)
            "setup_${setup_type}_python" "$local_flag" "$parallels_per_platform" "$NOW_RUN_LOG_FILE"
            log_section "✅ Results"
            identify_run_status_python "$NOW_RUN_LOG_FILE"
            check_return_value $? "$NOW_RUN_LOG_FILE" "${setup_type} setup succeeded." "❌ ${setup_type} setup failed. Check $log_file for details"
        ;;
        nodejs)
            "setup_${setup_type}_nodejs" "$local_flag" "$parallels_per_platform" "$NOW_RUN_LOG_FILE"
            log_section "✅ Results"
            identify_run_status_nodejs "$NOW_RUN_LOG_FILE"
            check_return_value $? "$NOW_RUN_LOG_FILE" "${setup_type} setup succeeded." "❌ ${setup_type} setup failed. Check $log_file for details"
        ;;
        *)
            log_warn "Unknown TECH_STACK: $tech_stack" "$NOW_RUN_LOG_FILE"
            return 1
        ;;
    esac
}

setup_web_java() {
    local local_flag=$1
    local parallels=$2
    
    REPO="now-testng-browserstack"
    TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"
    
    mkdir -p "$WORKSPACE_DIR/$PROJECT_FOLDER"
    
    clone_repository "$REPO" "$TARGET_DIR"
    
    cd "$TARGET_DIR"|| return 1
    
    log_info "Target website: $CX_TEST_URL"
    
    if is_domain_private; then
        local_flag=true
    fi
    
    report_bstack_local_status "$local_flag"
    
    # === 5️⃣ YAML Setup ===
    log_msg_to "🧩 Generating YAML config (bstack.yml)"
    
    
    # YAML config path
    export BROWSERSTACK_CONFIG_FILE="./browserstack.yml"
    platform_yaml=$(generate_web_platforms "$TEAM_PARALLELS_MAX_ALLOWED_WEB", "yaml")
    
  cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
platforms:
$platform_yaml
EOF
    
    export BSTACK_PARALLELS=$parallels
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_LOCAL=$local_flag
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-web-java-testng"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-web"
    
    # === 6️⃣ Build and Run ===
    log_msg_to "⚙️ Running 'mvn install -DskipTests'"
    log_info "Installing dependencies"
    mvn install -DskipTests >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1
    log_success "Dependencies installed"
    
    print_env_vars
    
    
    print_tests_running_log_section "mvn test -P sample-test"
    log_msg_to "🚀 Running 'mvn test -P sample-test'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/"
    mvn test -P sample-test >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!|| return 1
    
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    
    cd "$WORKSPACE_DIR/$PROJECT_FOLDER" || return 1
    return 0
}

setup_app_java() {
    local local_flag=$1
    local parallels=$2
    local log_file=$3
    
    REPO="now-testng-appium-app-browserstack"
    TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"
    local app_url=$BROWSERSTACK_APP
    log_msg_to "APP_PLATFORM: $APP_PLATFORM" >> "$NOW_RUN_LOG_FILE" 2>&1
    
    clone_repository "$REPO" "$TARGET_DIR"
    
    if [[ "$APP_PLATFORM" == "all" || "$APP_PLATFORM" == "android" ]]; then
        cd "android/testng-examples" || return 1
    else
        cd ios/testng-examples || return 1
    fi
    
    
    # YAML config path
    export BROWSERSTACK_CONFIG_FILE="./browserstack.yml"
    platform_yaml=$(generate_mobile_platforms "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE" "yaml")
    
    cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
app: ${app_url}
platforms:
$platform_yaml
EOF
    
    export BSTACK_PARALLELS=$parallels
    export BROWSERSTACK_LOCAL=true
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-app-java-testng"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-app"
    
    
    # Run Maven install first
    log_msg_to "⚙️ Running 'mvn clean'"
    log_info "Installing dependencies"
    if ! mvn clean >> "$NOW_RUN_LOG_FILE"  2>&1; then
        log_msg_to "❌ 'mvn clean' FAILED. See $log_file for details."
        return 1 # Fail the function if clean fails
    fi
    log_success "Dependencies installed"
    
    print_env_vars
    
    log_msg_to "🚀 Running 'mvn test -P sample-test'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/"
    print_tests_running_log_section "mvn test -P sample-test"
    mvn test -P sample-test >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!|| return 1
    
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    
    cd "$WORKSPACE_DIR/$PROJECT_FOLDER" || return 1
    return 0
}

setup_web_python() {
    local local_flag=$1
    local parallels=$2
    local log_file=$3
    
    REPO="now-pytest-browserstack"
    TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"
    
    clone_repository "$REPO" "$TARGET_DIR" ""
    
    detect_setup_python_env
    
    pip3 install --only-binary grpcio -r requirements.txt >> "$NOW_RUN_LOG_FILE" 2>&1
    pip3 uninstall -y pytest-html pytest-rerunfailures >> "$NOW_RUN_LOG_FILE" 2>&1
    log_success "Dependencies installed"
    
    # Update YAML at root level (browserstack.yml)
    export BROWSERSTACK_CONFIG_FILE="./browserstack.yml"
    platform_yaml=$(generate_web_platforms "$TEAM_PARALLELS_MAX_ALLOWED_WEB" "yaml")
    export BSTACK_PLATFORMS=$platform_yaml
      cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
platforms:
$platform_yaml
EOF
    
    if is_domain_private; then
        local_flag=true
    else
        local_flag=false
    fi
    
    
    export BSTACK_PARALLELS=1
    export BROWSERSTACK_LOCAL=$local_flag
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-web-python-pytest"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-web"
    
    report_bstack_local_status "$local_flag"

    print_env_vars    
    
    print_tests_running_log_section "browserstack-sdk pytest -s tests/*.py"
    log_msg_to "🚀 Running 'browserstack-sdk pytest -s tests/*.py'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/"
    # Run tests
    browserstack-sdk pytest -s tests/*.py >> "$NOW_RUN_LOG_FILE" 2>&1 & cmd_pid=$!|| return 1
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    
    cd "$WORKSPACE_DIR/$PROJECT_FOLDER" || return 1
    return 0
}

setup_app_python() {
    local local_flag=$1
    local parallels=$2
    local log_file=$3
    
    REPO="now-pytest-appium-app-browserstack"
    TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"
    
    clone_repository "$REPO" "$TARGET_DIR"
    
    # detect_setup_python_env
    
    # Install dependencies
    pip3 install --only-binary grpcio -r requirements.txt >> "$NOW_RUN_LOG_FILE" 2>&1
    log_success "Dependencies installed"
    
    local app_url=$BROWSERSTACK_APP
    local platform_yaml
    
    export BSTACK_PARALLELS=1
    
    # Decide which directory to run based on APP_PLATFORM (default to android)
    local run_dir="android"
    if [ "$APP_PLATFORM" = "ios" ]; then
        run_dir="ios"
    fi

        export BROWSERSTACK_CONFIG_FILE="./$run_dir/browserstack.yml"
    platform_yaml=$(generate_mobile_platforms "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE" "yaml")
    
    cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF

platforms:
$platform_yaml
EOF
    
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_LOCAL=true
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-app-python-pytest"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-app"
    
    print_env_vars
    
    print_tests_running_log_section "cd $run_dir && browserstack-sdk pytest -s bstack-sample.py"
    # Run pytest with BrowserStack SDK from the chosen platform directory
    log_msg_to "🚀 Running 'cd $run_dir && browserstack-sdk pytest -s bstack_sample.py'"
    (
        cd "$run_dir" && browserstack-sdk pytest -s bstack_sample.py >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1 & cmd_pid=$!|| return 1
        show_spinner "$cmd_pid"
        wait "$cmd_pid"
    )
    
    deactivate
    cd "$WORKSPACE_DIR/$PROJECT_FOLDER" || return 1
    return 0
}

setup_web_nodejs() {
    local local_flag=$1
    local parallels=$2
    
    REPO="now-webdriverio-browserstack"
    TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"
    mkdir -p "$WORKSPACE_DIR/$PROJECT_FOLDER"
    
    clone_repository "$REPO" "$TARGET_DIR"
    
    
    # === 2️⃣ Install Dependencies ===
    log_msg_to "⚙️ Running 'npm install'"
    log_info "Installing dependencies"
    npm install >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1
    log_success "Dependencies installed"
    
    local caps_json=""
    # === 4️⃣ Generate Capabilities JSON ===
    caps_json=$(generate_web_platforms "$parallels" "json")
    export BSTACK_CAPS_JSON=$caps_json
    export BSTACK_PARALLELS=$parallels
    
    if is_domain_private; then
        local_flag=true
    fi
    
    export BROWSERSTACK_LOCAL=$local_flag
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-web-nodejs-wdio"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-web"
    
    report_bstack_local_status "$local_flag"
    
    print_env_vars
    
    # === 8️⃣ Run Tests ===
    log_msg_to "🚀 Running 'npm run test'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/"
    print_tests_running_log_section "npm run test"
    npm run test >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1 &
    cmd_pid=$!|| return 1
    
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    
    cd "$WORKSPACE_DIR/$PROJECT_FOLDER" || return 1
    return 0
}

setup_app_nodejs() {
    local local_flag=$1
    local parallels=$2
    local log_file=$3
    local caps_json=""
    
    log_msg_to "Starting Mobile NodeJS setup with parallels: $parallels" >> "$NOW_RUN_LOG_FILE" 2>&1
    mkdir -p "$WORKSPACE_DIR/$PROJECT_FOLDER"
    REPO="now-webdriverio-appium-app-browserstack"
    TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"
    TEST_FOLDER="/test"
    
    clone_repository $REPO "$TARGET_DIR" "$TEST_FOLDER"
    
    # === 2️⃣ Install Dependencies ===
    log_info "Installing dependencies"
    log_msg_to "⚙️ Running 'npm install'"
    npm install >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1
    log_success "Dependencies installed"
    
    caps_json=$(generate_mobile_platforms "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE" "json")
    
    
    export BSTACK_CAPS_JSON=$caps_json
    
    local app_url=$BROWSERSTACK_APP
    
    export BSTACK_PARALLELS=$parallels
    export BROWSERSTACK_LOCAL=true
    export BROWSERSTACK_APP=$app_url
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-app-nodejs-wdio"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-app"
    
    print_env_vars
    
    # === 8️⃣ Run Tests ===
    log_msg_to "🚀 Running 'npm run test'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/"
    print_tests_running_log_section "npm run test"
    npm run test >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1 &
    cmd_pid=$!|| return 1
    
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    
    # === 9️⃣ Wrap Up ===
    log_msg_to "✅ Mobile JS setup and test execution completed successfully."
    
    cd "$WORKSPACE_DIR/$PROJECT_FOLDER" || return 1
    return 0
}

clone_repository() {
    local repo_git=$1
    local install_folder=$2
    local test_folder=$3
    local git_branch=$4
    
    rm -rf "$install_folder"
    log_msg_to "📦 Cloning repo $repo_git into $install_folder"
    log_info "Cloning repository: $repo_git"
    # git clone https://github.com/BrowserStackCE/"$repo_git".git "$install_folder" >> "$NOW_RUN_LOG_FILE"  2>&1 || return 1
    if [ -z "$git_branch" ]; then
        # git_branch is null or empty
        git clone "https://github.com/BrowserStackCE/$repo_git.git" \
        "$install_folder" >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1
    else
        # git_branch has a value
        git clone -b "$git_branch" "https://github.com/BrowserStackCE/$repo_git.git" \
        "$install_folder" >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1
    fi
    log_msg_to "✅ Cloned repository: $repo_git into $install_folder"
    cd "$install_folder/$test_folder" || return 1
}

# ===== Orchestration: decide what to run based on TEST_TYPE and plan fetch =====
run_setup_wrapper() {
    local test_type=$1
    local tech_stack=$2
    log_msg_to "Orchestration: TEST_TYPE=$test_type, WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED, MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED"
    
    case "$test_type" in
        Web)
            if [ "$WEB_PLAN_FETCHED" == true ]; then
                run_setup "$test_type" "$tech_stack"
            else
                log_msg_to "⚠️ Skipping Web setup — Web plan not fetched"
            fi
        ;;
        App)
            if [ "$MOBILE_PLAN_FETCHED" == true ]; then
                run_setup "$test_type" "$tech_stack"
            else
                log_msg_to "⚠️ Skipping Mobile setup — Mobile plan not fetched"
            fi
        ;;
        *)
            log_msg_to "❌ Invalid TEST_TYPE: $test_type"
            exit 1
        ;;
    esac
}

check_return_value() {
    local return_value=$1
    local log_file=$2
    local success_message=$3
    local failure_message=$4
    
    if [ "$return_value" -eq 0 ]; then
        log_success "$success_message" "$NOW_RUN_LOG_FILE"
        exit 0
    else
        log_error "$failure_message" "$NOW_RUN_LOG_FILE"
        exit 1
    fi
}


report_bstack_local_status() {
    if [ "$local_flag" = "true" ]; then
        log_msg_to "✅ BrowserStack Local is ENABLED for this run."
        log_success "Target website is behind firewall. BrowserStack Local enabled for this run."
    else
        log_msg_to "✅ BrowserStack Local is DISABLED for this run."
        log_success "Target website is publicly resolvable. BrowserStack Local disabled for this run."
    fi
}

print_tests_running_log_section() {
    log_section "🚀 Running Tests: $1"
    log_info "Executing: Test run command. This could take a few minutes..."
    log_info "You can monitor test progress here: 🔗 https://automation.browserstack.com/"
}


detect_setup_python_env() {
    log_info "Detecting latest Python environment"
    
    latest_python=$(
        { ls -1 /usr/local/bin/python3.[0-9]* /usr/bin/python3.[0-9]* 2>/dev/null || true; } \
        | grep -E 'python3\.[0-9]+$' \
        | sort -V \
        | tail -n 1
    )
    
    if [[ -z "$latest_python" ]]; then
        log_warn "No specific Python3.x version found. Falling back to system python3."
        latest_python=$(command -v python3)
    fi
    
    if [[ -z "$latest_python" ]]; then
        log_error "Python3 not found on this system."
        exit 1
    fi
    
    echo "🐍 Switching to: $latest_python"
    log_info "Using Python interpreter: $latest_python"
    
    "$latest_python" -m venv .venv || {
        log_error "Failed to create virtual environment."
        exit 1
    }
    
    # Activate virtual environment (handle Windows/Unix paths)
    if [ -f ".venv/Scripts/activate" ]; then
        # shellcheck source=/dev/null
        source .venv/Scripts/activate
    else
        # shellcheck source=/dev/null
        source .venv/bin/activate
    fi
    log_success "Virtual environment created and activated."
}

print_env_vars() {
    log_section "✅ Environment Variables"
    log_info "BrowserStack Username: $BROWSERSTACK_USERNAME"
    log_info "BrowserStack Project Name: $BROWSERSTACK_PROJECT_NAME"
    log_info "BrowserStack Build: $BROWSERSTACK_BUILD_NAME"
    log_info "BrowserStack Local Flag: $BROWSERSTACK_LOCAL"
    log_info "Parallels per platform: $BSTACK_PARALLELS"

    if [ "$tech_stack" = "nodejs" ]; then
        log_info "Capabilities JSON: \n$BSTACK_CAPS_JSON"
    else
        log_info "Platforms: \n$BSTACK_PLATFORMS"
    fi
    
    if [ "$test_type" = "app" ]; then
        log_info "Native App Endpoint: $BROWSERSTACK_APP"
    else
        log_info "Web Application Endpoint: $CX_TEST_URL"
    fi
}