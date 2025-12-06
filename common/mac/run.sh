#!/bin/bash
set -o pipefail

# Import utilities
# shellcheck source=/dev/null
source "$(dirname "$0")/common-utils.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/logging-utils.sh"

# shellcheck source=/dev/null
source "$(dirname "$0")/env-setup-run.sh"

# shellcheck source=/dev/null
source "$(dirname "$0")/user-interaction.sh"
# shellcheck source=/dev/null
source "$(dirname "$0")/env-prequisite-checks.sh"

# ===== Web wrapper with retry logic (writes runtime logs to $NOW_RUN_LOG_FILE) =====
# Wrapper functions using the common setup_environment function
run_setup() {
    local test_type=$1
    local tech_stack=$2
    setup_environment "$test_type" "$tech_stack"
}


# ===== Main flow (baseline steps then run) =====

detect_os


RUN_MODE=$1  # --interactive or --silent / --debug
TT=$2  # Testing Type from env (for silent mode)
TSTACK=$3  # Tech Stack from env (for silent mode)
CLI_TEST_URL=$4
CLI_APP_PATH=$5
CLI_APP_PLATFORM=$6

export CLI_TEST_URL
export CLI_APP_PATH
export CLI_APP_PLATFORM

log_section "🧭 Setup Summary – BrowserStack NOW"
log_info "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"


log_file=""
if [[ "$RUN_MODE" == *"--silent"* || "$RUN_MODE" == *"--debug"* ]]; then
    TEST_TYPE=$TT
    TECH_STACK=$TSTACK
    log_file="$LOG_DIR/${TEST_TYPE:unknown}_${TECH_STACK:unknown}_run_result.log"
    log_info "Run Mode: ${RUN_MODE:-default}"
else
    get_test_type "$RUN_MODE"
    get_tech_stack "$RUN_MODE"
    log_file="$LOG_DIR/${TEST_TYPE:unknown}_${TECH_STACK:unknown}_run_result.log"
    perform_next_steps_based_on_test_type "$TEST_TYPE"
fi

log_info "Log file path: $log_file"
export NOW_RUN_LOG_FILE="$log_file"
setup_workspace
get_browserstack_credentials "$RUN_MODE"

log_section "⚙️ Platform & Tech Stack"
log_info "Platform: ${TEST_TYPE:-N/A}"
log_info "Tech Stack: ${TECH_STACK:-N/A}"

validate_tech_stack_installed "$TECH_STACK"
fetch_plan_details "$TEST_TYPE"

if [[ "$RUN_MODE" == *"--silent"* || "$RUN_MODE" == *"--debug"* ]]; then
    if [[ $TEST_TYPE == "app" ]]; then
        get_upload_app
        log_success "Sample App uploaded successfully"
    fi
fi

log_msg_to "Plan summary: WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_WEB), MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE)"
log_msg_to "Checking proxy in environment"
set_proxy_in_env

log_section "🧹 Getting Ready"
log_info "Detected Operating system: $NOW_OS"
log_info "Clearing old logs fron NOW Home Directory inside .browserstack"

clear_old_logs

log_info "Starting $TEST_TYPE setup for $TECH_STACK"
setup_environment "$TEST_TYPE" "$TECH_STACK"

