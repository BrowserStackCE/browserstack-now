#!/usr/bin/env sh

# URL to test
TEST_URL="https://www.browserstack.com/automate/browsers.json"

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
    p="${p#*[@]}"

    # extract host and port
    export PROXY_HOST="${p%%:*}"
    export PROXY_PORT="${p##*:}"
}

base64_encoded_creds=$(printf "%s" $BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY | base64 | tr -d '\n')


# If no proxy configured, exit early
if [ -z "$PROXY" ]; then
    echo "No proxy found in environment. Clearing proxy host and port variables."
    export PROXY_HOST=""
    export PROXY_PORT=""
    return 0 2>/dev/null || exit 0
fi

echo "Proxy detected: $PROXY"
parse_proxy "$PROXY"

echo "Testing reachability via proxy..."


STATUS_CODE=$(curl -sS -o /dev/null -H "Authorization: Basic ${base64_encoded_creds}" -w "%{http_code}" --proxy "$PROXY" "$TEST_URL" 2>/dev/null)

if [ "${STATUS_CODE#2}" != "$STATUS_CODE" ]; then
    echo "✅ Reachable. HTTP $STATUS_CODE"
    echo "Exporting PROXY_HOST=$PROXY_HOST"
    echo "Exporting PROXY_PORT=$PROXY_PORT"
    export PROXY_HOST
    export PROXY_PORT
else
    echo "❌ Not reachable (HTTP $STATUS_CODE). Clearing variables."
    export PROXY_HOST=""
    export PROXY_PORT=""
fi
