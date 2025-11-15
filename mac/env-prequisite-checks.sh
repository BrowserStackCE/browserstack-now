#!/bin/bash

# URL to test
PROXY_TEST_URL="https://www.browserstack.com/automate/browsers.json"

# Detect proxy from env (case insensitive)
PROXY="${http_proxy:-${HTTP_PROXY:-${https_proxy:-${HTTPS_PROXY}}}}"

# Reset output variables
export PROXY_HOST=""
export PROXY_PORT=""

# Function: parse proxy url to host + port
parse_proxy() {
    p="$1"
    # strip protocol e.g. http://, https://
    p="${p#http://}"
    p="${p#https://}"
    # strip credentials if any user:pass@
    p="${p#*@}"
    
    # extract host and port
    export PROXY_HOST="${p%%:*}"
    export PROXY_PORT="${p##*:}"
}

set_proxy_in_env() {
    log_section "🌐 Network & Proxy Validation"
    base64_encoded_creds=$(printf "%s" $BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY | base64 | tr -d '\n')
    
    
    # If no proxy configured, exit early
    if [ -z "$PROXY" ]; then
        log_warn "No proxy found. Using direct connection."
        export PROXY_HOST=""
        export PROXY_PORT=""
        return 0 2>/dev/null || exit 0
    fi
    
    log_msg_to "Proxy detected: $PROXY"
    parse_proxy "$PROXY"
    
    log_msg_to "Testing reachability via proxy..."
    
    
    STATUS_CODE=$(curl -sS -o /dev/null -H "Authorization: Basic ${base64_encoded_creds}" -w "%{http_code}" --proxy "$PROXY" "$PROXY_TEST_URL" 2>/dev/null)
    
    if [ "${STATUS_CODE#2}" != "$STATUS_CODE" ]; then
        log_msg_to "✅ Reachable. HTTP $STATUS_CODE"
        log_msg_to "Exporting PROXY_HOST=$PROXY_HOST"
        log_msg_to "Exporting PROXY_PORT=$PROXY_PORT"
        export PROXY_HOST
        export PROXY_PORT
        log_success "Connected to BrowserStack from proxy: $PROXY_HOST:$PROXY_PORT"
    else
        log_warn "⚠️ Could not connect to BrowserStack using proxy. Using direct connection."
        log_msg_to "❌ Not reachable (HTTP $STATUS_CODE). Clearing variables."
        export PROXY_HOST=""
        export PROXY_PORT=""
    fi
}


# ===== Tech Stack Validation Functions =====
check_java_installation() {
    log_msg_to "🔍 Checking if 'java' command exists..."
    if ! command -v java >/dev/null 2>&1; then
        log_msg_to "❌ Java command not found in PATH."
        return 1
    fi
    
    log_msg_to "🔍 Checking if Java runs correctly..."
    if ! JAVA_VERSION_OUTPUT=$(java -version 2>&1); then
        log_msg_to "❌ Java exists but failed to run."
        return 1
    fi
    
    log_success "Java installed and functional\n$JAVA_VERSION_OUTPUT"
    #log_msg_to "$JAVA_VERSION_OUTPUT" | while read -r l; do log_msg_to "  $l" ; done
    return 0
}

check_python_installation() {
    log_msg_to "🔍 Checking if 'python3' command exists..."
    if ! command -v python3 >/dev/null 2>&1; then
        log_msg_to "❌ Python3 command not found in PATH."
        return 1
    fi
    
    log_msg_to "🔍 Checking if Python3 runs correctly..."
    if ! PYTHON_VERSION_OUTPUT=$(python3 --version 2>&1); then
        log_msg_to "❌ Python3 exists but failed to run."
        return 1
    fi
    
    log_success "Python3 default installation: $PYTHON_VERSION_OUTPUT"
    return 0
}

check_nodejs_installation() {
    log_msg_to "🔍 Checking if 'node' command exists..."
    if ! command -v node >/dev/null 2>&1; then
        log_msg_to "❌ Node.js command not found in PATH."
        return 1
    fi
    
    log_msg_to "🔍 Checking if 'npm' command exists..."
    if ! command -v npm >/dev/null 2>&1; then
        log_msg_to "❌ npm command not found in PATH."
        return 1
    fi
    
    log_msg_to "🔍 Checking if Node.js runs correctly..."
    if ! NODE_VERSION_OUTPUT=$(node -v 2>&1); then
        log_msg_to "❌ Node.js exists but failed to run."
        return 1
    fi
    
    log_msg_to "🔍 Checking if npm runs correctly..."
    if ! NPM_VERSION_OUTPUT=$(npm -v 2>&1); then
        log_msg_to "❌ npm exists but failed to run."
        return 1
    fi
    
    log_success "Node.js installed: $NODE_VERSION_OUTPUT"
    log_success "npm installed: $NPM_VERSION_OUTPUT"
    return 0
}

validate_tech_stack_installed() {
    local tech_stack=$1
    
    log_section "🧩 System Prerequisites Check"
    log_info "Checking prerequisites for $tech_stack"
    
    case "$tech_stack" in
        java)
            check_java_installation
        ;;
        python)
            check_python_installation
        ;;
        nodejs)
            check_nodejs_installation
        ;;
        *)
            log_msg_to "❌ Unknown tech stack selected: $tech_stack"
            return 1
        ;;
    esac
    
    log_msg_to "✅ Prerequisites validated for $tech_stack"
    return 0
}



