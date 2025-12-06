#!/usr/bin/env bash
# shellcheck shell=bash

REPO_CONFIG="$(dirname "$0")/../config/repos.txt"

get_repo_name() {
    local key="$1"
    local repo=""
    while IFS= read -r line; do
        if [[ "$line" == "$key|"* ]]; then
            repo="${line#*|}"
            echo "$repo"
            return
        fi
    done < "$REPO_CONFIG"
}

setup_environment() {
    local setup_type=$1
    local tech_stack=$2
    local max_parallels
    
    log_section "📦 Project Setup"
    
    if [ "$setup_type" = "web" ]; then
        max_parallels=$TEAM_PARALLELS_MAX_ALLOWED_WEB
    else
        max_parallels=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE
    fi
    
    log_msg_to "Starting ${setup_type} setup for $tech_stack" "$NOW_RUN_LOG_FILE"
    
    local total_parallels=$max_parallels
    [ -z "$total_parallels" ] && total_parallels=1
    
    local repo_key="${setup_type}_${tech_stack}"
    local repo_name=$(get_repo_name "$repo_key")
    
    if [ -z "$repo_name" ]; then
        log_error "Unknown combination: $repo_key"
        return 1
    fi
    
    local target_dir="$WORKSPACE_DIR/$PROJECT_FOLDER/$repo_name"
    clone_repository "$repo_name" "$target_dir"
    
    # Dispatch to specific setup function
    "setup_${setup_type}_${tech_stack}" "$target_dir" "$total_parallels"
    
    local ret=$?

    log_section "✅ Results"
    log_info "${setup_type} setup completed with exit code: $ret"
    local status=1
    #if [ $ret -eq 0 ]; then
    "identify_run_status_${tech_stack}" "$NOW_RUN_LOG_FILE"
    status=$?
    #fi

    if [ $status -eq 0 ]; then
        log_success "${setup_type} setup succeeded."
    else
        log_error "${setup_type} setup failed."
        exit 1
    fi
}

setup_web_java() {
    local cwd=$1
    local parallels=$2
    cd "$cwd" || return 1
    
    if is_domain_private; then local_flag=true; else local_flag=false; fi
    report_bstack_local_status "$local_flag"
    
    export BROWSERSTACK_CONFIG_FILE="./browserstack.yml"
    platform_yaml=$(generate_web_platforms "$parallels" "yaml")
    cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
platforms:
$platform_yaml
EOF
    export BSTACK_PARALLELS=$parallels
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_LOCAL=$local_flag
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-web-java-testng"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-web"
    
    log_info "Installing dependencies"
    mvn install -DskipTests >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1

    print_env_vars
    
    
    log_info "Running tests..."
    mvn test -P sample-test >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    return $?
}

setup_app_java() {
    local root_dir=$1
    local parallels=$2
    
    if [[ "$APP_PLATFORM" == "all" || "$APP_PLATFORM" == "android" ]]; then
        cd "$root_dir/android/testng-examples" || return 1
    else
        cd "$root_dir/ios/testng-examples" || return 1
    fi
    
    export BROWSERSTACK_CONFIG_FILE="./browserstack.yml"
    platform_yaml=$(generate_mobile_platforms "$parallels" "yaml")
    cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
app: ${BROWSERSTACK_APP}
platforms:
$platform_yaml
EOF
    export BSTACK_PARALLELS=$parallels
    export BROWSERSTACK_LOCAL=true
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-app-java-testng"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-app"

    print_env_vars
    
    log_info "Installing dependencies"
    mvn clean >> "$NOW_RUN_LOG_FILE" 2>&1 || return 1
    
    log_info "Running tests..."
    mvn test -P sample-test >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    return $?
}

setup_web_python() {
    local cwd=$1
    local parallels=$2
    cd "$cwd" || return 1
    
    detect_setup_python_env
    pip3 install --only-binary grpcio -r requirements.txt >> "$NOW_RUN_LOG_FILE" 2>&1
    
    export BROWSERSTACK_CONFIG_FILE="./browserstack.yml"
    platform_yaml=$(generate_web_platforms "$parallels" "yaml")
    cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
platforms:
$platform_yaml
EOF
    if is_domain_private; then local_flag=true; else local_flag=false; fi
    export BSTACK_PARALLELS=1
    export BROWSERSTACK_LOCAL=$local_flag
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-web-python-pytest"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-web"

    print_env_vars
    
    log_info "Running tests..."
    browserstack-sdk pytest -s tests/*.py >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    return $?
}

setup_app_python() {
    local cwd=$1
    local parallels=$2
    cd "$cwd" || return 1
    
    detect_setup_python_env
    pip install --only-binary grpcio -r requirements.txt >> "$NOW_RUN_LOG_FILE" 2>&1
    
    local run_dir="android"
    if [ "$APP_PLATFORM" = "ios" ]; then run_dir="ios"; fi
    
    export BROWSERSTACK_CONFIG_FILE="./$run_dir/browserstack.yml"
    platform_yaml=$(generate_mobile_platforms "$parallels" "yaml")
    cat >> "$BROWSERSTACK_CONFIG_FILE" <<EOF
platforms:
$platform_yaml
EOF
    export BSTACK_PARALLELS=1
    export BROWSERSTACK_LOCAL=true
    export BSTACK_PLATFORMS=$platform_yaml
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-app-python-pytest"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-app"

    print_env_vars
    
    log_info "Running tests..."
    (
        cd "$run_dir" && browserstack-sdk pytest -s bstack_sample.py >> "$NOW_RUN_LOG_FILE" 2>&1
    ) &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    return $?
}

setup_web_nodejs() {
    local cwd=$1
    local parallels=$2
    cd "$cwd" || return 1
    
    npm install >> "$NOW_RUN_LOG_FILE" 2>&1
    
    caps_json=$(generate_web_platforms "$parallels" "json")
    export BSTACK_CAPS_JSON=$caps_json
    export BSTACK_PARALLELS=$parallels
    if is_domain_private; then local_flag=true; else local_flag=false; fi
    export BROWSERSTACK_LOCAL=$local_flag
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-web-nodejs-wdio"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-web"

    print_env_vars
    
    log_info "Running tests..."
    npm run test >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    return $?
}

setup_app_nodejs() {
    local root_dir=$1
    local parallels=$2
    # App nodejs clones into root, but tests are in root/test?
    # Original script: clone_repository $REPO "$TARGET_DIR" "$TEST_FOLDER" where TEST_FOLDER="/test"
    # clone_repository does cd "$install_folder/$test_folder"
    # So we should cd to test folder.
    cd "$root_dir/test" || return 1
    
    npm install >> "$NOW_RUN_LOG_FILE" 2>&1
    
    caps_json=$(generate_mobile_platforms "$parallels" "json")
    export BSTACK_CAPS_JSON=$caps_json
    export BSTACK_PARALLELS=$parallels
    export BROWSERSTACK_LOCAL=true
    export BROWSERSTACK_APP=$BROWSERSTACK_APP
    export BROWSERSTACK_BUILD_NAME="now-$NOW_OS-app-nodejs-wdio"
    export BROWSERSTACK_PROJECT_NAME="now-$NOW_OS-app"

    print_env_vars
    
    log_info "Running tests..."
    npm run test >> "$NOW_RUN_LOG_FILE" 2>&1 &
    cmd_pid=$!
    show_spinner "$cmd_pid"
    wait "$cmd_pid"
    return $?
}

clone_repository() {
    local repo_git=$1
    local install_folder=$2
    rm -rf "$install_folder"
    log_info "Cloning $repo_git..."
    git clone "https://github.com/BrowserStackCE/$repo_git.git" "$install_folder" >> "$NOW_RUN_LOG_FILE" 2>&1
}

detect_setup_python_env() {
    log_info "Setting up Python environment..."
    python3 -m venv .venv
    if [ -f ".venv/bin/activate" ]; then
        source .venv/bin/activate
    else
        source .venv/Scripts/activate
    fi
}

print_env_vars() {
    log_section "Validate Environment Variables and Platforms"
    log_info "BrowserStack Username: $BROWSERSTACK_USERNAME"
    log_info "BrowserStack Project Name: $BROWSERSTACK_PROJECT_NAME"
    log_info "BrowserStack Build: $BROWSERSTACK_BUILD_NAME"
    if [ $TEST_TYPE == "app" ]; then
        log_info "Native App Endpoint: $BROWSERSTACK_APP"
    fi
    log_info "BrowserStack Local Flag: $BROWSERSTACK_LOCAL"
    log_info "Parallels per platform: $BSTACK_PARALLELS"
    log_info "Platforms: \n$BSTACK_PLATFORMS"
}
