#!/bin/bash
set -o pipefail

# ===== Global Variables =====
WORKSPACE_DIR="$HOME/.browserstack"
PROJECT_FOLDER="NOW"

BROWSERSTACK_USERNAME=""
BROWSERSTACK_ACCESS_KEY=""
TEST_TYPE=""       # Web / App / Both
TECH_STACK=""      # Java / Python / JS

PARALLEL_PERCENTAGE=1.00

WEB_PLAN_FETCHED=false
MOBILE_PLAN_FETCHED=false
TEAM_PARALLELS_MAX_ALLOWED_WEB=0
TEAM_PARALLELS_MAX_ALLOWED_MOBILE=0

# URL handling
DEFAULT_TEST_URL="https://bstackdemo.com"
CX_TEST_URL="$DEFAULT_TEST_URL"

# Global vars
APP_URL=""
APP_PLATFORM=""   # ios | android | all


# ===== Error Patterns =====
WEB_SETUP_ERRORS=("")
WEB_LOCAL_ERRORS=("")

MOBILE_SETUP_ERRORS=("")
MOBILE_LOCAL_ERRORS=("")

# ===== Example Platform Templates (replace with your full lists if available) =====
WEB_PLATFORM_TEMPLATES=(
  "Windows|10|Chrome"
  "Windows|10|Firefox"
  "Windows|11|Edge"
  "Windows|11|Chrome"
  "Windows|8|Chrome"
  #"OS X|Monterey|Safari"
  "OS X|Monterey|Chrome"
  "OS X|Ventura|Chrome"
  #"OS X|Big Sur|Safari"
  "OS X|Catalina|Firefox"
)


MOBILE_ALL=(
  # Tier 1
  "ios|iPhone 15|17"
  "ios|iPhone 15 Pro|17"
  "ios|iPhone 16|18"
  "android|Samsung Galaxy S25|15"
  "android|Samsung Galaxy S24|14"

  # Tier 2
  "ios|iPhone 14 Pro|16"
  "ios|iPhone 14|16"
  "ios|iPad Air 13 2025|18"
  "android|Samsung Galaxy S23|13"
  "android|Samsung Galaxy S22|12"
  "android|Samsung Galaxy S21|11"
  "android|Samsung Galaxy Tab S10 Plus|15"

  # Tier 3
  "ios|iPhone 13 Pro Max|15"
  "ios|iPhone 13|15"
  "ios|iPhone 12 Pro|14"
  "ios|iPhone 12 Pro|17"
  "ios|iPhone 12|17"
  "ios|iPhone 12|14"
  "ios|iPhone 12 Pro Max|16"
  "ios|iPhone 13 Pro|15"
  "ios|iPhone 13 Mini|15"
  "ios|iPhone 16 Pro|18"
  "ios|iPad 9th|15"
  "ios|iPad Pro 12.9 2020|14"
  "ios|iPad Pro 12.9 2020|16"
  "ios|iPad 8th|16"
  "android|Samsung Galaxy S22 Ultra|12"
  "android|Samsung Galaxy S21|12"
  "android|Samsung Galaxy S21 Ultra|11"
  "android|Samsung Galaxy S20|10"
  "android|Samsung Galaxy M32|11"
  "android|Samsung Galaxy Note 20|10"
  "android|Samsung Galaxy S10|9"
  "android|Samsung Galaxy Note 9|8"
  "android|Samsung Galaxy Tab S8|12"
  "android|Google Pixel 9|15"
  "android|Google Pixel 6 Pro|13"
  "android|Google Pixel 8|14"
  "android|Google Pixel 7|13"
  "android|Google Pixel 6|12"
  "android|Vivo Y21|11"
  "android|Vivo Y50|10"
  "android|Oppo Reno 6|11"

  # Tier 4
  "ios|iPhone 15 Pro Max|17"
  "ios|iPhone 15 Pro Max|26"
  "ios|iPhone 15|26"
  "ios|iPhone 15 Plus|17"
  "ios|iPhone 14 Pro|26"
  "ios|iPhone 14|18"
  "ios|iPhone 14|26"
  "ios|iPhone 13 Pro Max|18"
  "ios|iPhone 13|16"
  "ios|iPhone 13|17"
  "ios|iPhone 13|18"
  "ios|iPhone 12 Pro|18"
  "ios|iPhone 14 Pro Max|16"
  "ios|iPhone 14 Plus|16"
  "ios|iPhone 11|13"
  "ios|iPhone 8|11"
  "ios|iPhone 7|10"
  "ios|iPhone 17 Pro Max|26"
  "ios|iPhone 17 Pro|26"
  "ios|iPhone 17 Air|26"
  "ios|iPhone 17|26"
  "ios|iPhone 16e|18"
  "ios|iPhone 16 Pro Max|18"
  "ios|iPhone 16 Plus|18"
  "ios|iPhone SE 2020|16"
  "ios|iPhone SE 2022|15"
  "ios|iPad Air 4|14"
  "ios|iPad 9th|18"
  "ios|iPad Air 5|26"
  "ios|iPad Pro 11 2021|18"
  "ios|iPad Pro 13 2024|17"
  "ios|iPad Pro 12.9 2021|14"
  "ios|iPad Pro 12.9 2021|17"
  "ios|iPad Pro 11 2024|17"
  "ios|iPad Air 6|17"
  "ios|iPad Pro 12.9 2022|16"
  "ios|iPad Pro 11 2022|16"
  "ios|iPad 10th|16"
  "ios|iPad Air 13 2025|26"
  "ios|iPad Pro 11 2020|13"
  "ios|iPad Pro 11 2020|16"
  "ios|iPad 8th|14"
  "ios|iPad Mini 2021|15"
  "ios|iPad Pro 12.9 2018|12"
  "ios|iPad 6th|11"
  "android|Samsung Galaxy S23 Ultra|13"
  "android|Samsung Galaxy S22 Plus|12"
  "android|Samsung Galaxy S21 Plus|11"
  "android|Samsung Galaxy S20 Ultra|10"
  "android|Samsung Galaxy S25 Ultra|15"
  "android|Samsung Galaxy S24 Ultra|14"
  "android|Samsung Galaxy M52|11"
  "android|Samsung Galaxy A52|11"
  "android|Samsung Galaxy A51|10"
  "android|Samsung Galaxy A11|10"
  "android|Samsung Galaxy A10|9"
  "android|Samsung Galaxy Tab A9 Plus|14"
  "android|Samsung Galaxy Tab S9|13"
  "android|Samsung Galaxy Tab S7|10"
  "android|Samsung Galaxy Tab S7|11"
  "android|Samsung Galaxy Tab S6|9"
  "android|Google Pixel 9|16"
  "android|Google Pixel 10 Pro XL|16"
  "android|Google Pixel 10 Pro|16"
  "android|Google Pixel 10|16"
  "android|Google Pixel 9 Pro XL|15"
  "android|Google Pixel 9 Pro|15"
  "android|Google Pixel 6 Pro|12"
  "android|Google Pixel 6 Pro|15"
  "android|Google Pixel 8 Pro|14"
  "android|Google Pixel 7 Pro|13"
  "android|Google Pixel 5|11"
  "android|OnePlus 13R|15"
  "android|OnePlus 12R|14"
  "android|OnePlus 11R|13"
  "android|OnePlus 9|11"
  "android|OnePlus 8|10"
  "android|Motorola Moto G71 5G|11"
  "android|Motorola Moto G9 Play|10"
  "android|Vivo V21|11"
  "android|Oppo A96|11"
  "android|Oppo Reno 3 Pro|10"
  "android|Xiaomi Redmi Note 11|11"
  "android|Xiaomi Redmi Note 9|10"
  "android|Huawei P30|9"
)




APP_URL=""
APP_PLATFORM=""   # ios | android | all



# ===== Log files (runtime only; created on first write) =====
# ===== Log files (per-run) =====
LOG_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/logs"
GLOBAL="$LOG_DIR/global.log"
WEB_LOG_FILE="$LOG_DIR/web_run_result.log"
MOBILE_LOG_FILE="$LOG_DIR/mobile_run_result.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Clear old logs to start fresh
: > "$GLOBAL"
: > "$WEB_LOG_FILE"
: > "$MOBILE_LOG_FILE"


# ===== Logging helper (runtime timestamped logging) =====
# Usage: log_msg_to "message" "$DEST_FILE"  (DEST_FILE optional; prints to console always)
log_msg_to() {
  local message="$1"
  local dest_file="$2"    # optional
  local ts
  ts="$(date +"%Y-%m-%d %H:%M:%S")"
  local line="[$ts] $message"

  # print to console
  echo "$line"

  # write to dest file if provided
  if [ -n "$dest_file" ]; then
    mkdir -p "$(dirname "$dest_file")"
    echo "$line" >> "$dest_file"
  fi
}

# Spinner function
show_spinner() {
    local pid=$1
    local spin='|/-\'
    local i=0
	local ts
  	ts="$(date +"%Y-%m-%d %H:%M:%S")"
    while kill -0 "$pid" 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r[$ts] ⏳ Processing... ${spin:$i:1}"
        sleep 0.1
    done
    log_msg_to "✅ Done!"
}

# ===== validate_prereqs shim (keeps compatibility with older code) =====
validate_prereqs() {
  # For backwards compatibility call validate_tech_stack_installed
  validate_tech_stack_installed
}

# ===== Functions: baseline interactions =====
setup_workspace() {
    local full_path="$WORKSPACE_DIR/$PROJECT_FOLDER"
    if [ ! -d "$full_path" ]; then
        mkdir -p "$full_path"
        log_msg_to "✅ Created Onboarding workspace: $full_path" "$GLOBAL"
    else
        log_msg_to "ℹ️ Onboarding Workspace already exists: $full_path" "$GLOBAL"
    fi
}

ask_browserstack_credentials() {
    # Prompt username
    BROWSERSTACK_USERNAME=$(osascript -e 'Tell application "System Events" to display dialog "Please enter your BrowserStack Username.\n\nNote: Locate it in your BrowserStack account profile page.\nhttps://www.browserstack.com/accounts/profile/details" default answer "" with title "BrowserStack Setup" buttons {"OK"} default button "OK"' \
                            -e 'text returned of result')
    if [ -z "$BROWSERSTACK_USERNAME" ]; then
        log_msg_to "❌ Username empty" "$GLOBAL"
        exit 1
    fi

    # Prompt access key (hidden)
    BROWSERSTACK_ACCESS_KEY=$(osascript -e 'Tell application "System Events" to display dialog "Please enter your BrowserStack Access Key.\n\nNote: Locate it in your BrowserStack account page.\nhttps://www.browserstack.com/accounts/profile/details" default answer "" with hidden answer with title "BrowserStack Setup" buttons {"OK"} default button "OK"' \
                             -e 'text returned of result')
    if [ -z "$BROWSERSTACK_ACCESS_KEY" ]; then
        log_msg_to "❌ Access Key empty" "$GLOBAL"
        exit 1
    fi

    log_msg_to "✅ BrowserStack credentials captured (access key hidden)" "$GLOBAL"
}


ask_tech_stack() {
    TECH_STACK=$(osascript -e 'Tell application "System Events" to display dialog "Select installed tech stack:" buttons {"Java", "Python", "NodeJS"} default button "Java" with title "Testing Framework Technology Stack"' \
                        -e 'button returned of result')
    log_msg_to "✅ Selected Tech Stack: $TECH_STACK" "$GLOBAL"
}

validate_tech_stack_installed() {
    log_msg_to "ℹ️ Checking prerequisites for $TECH_STACK" "$GLOBAL"

    case "$TECH_STACK" in
        Java)
            log_msg_to "🔍 Checking if 'java' command exists..." "$GLOBAL"
            if ! command -v java >/dev/null 2>&1; then
                log_msg_to "❌ Java command not found in PATH." "$GLOBAL"
                exit 1
            fi

            log_msg_to "🔍 Checking if Java runs correctly..." "$GLOBAL"
            if ! JAVA_VERSION_OUTPUT=$(java -version 2>&1); then
                log_msg_to "❌ Java exists but failed to run." "$GLOBAL"
                exit 1
            fi

            log_msg_to "✅ Java is installed. Version details:" "$GLOBAL"
            echo "$JAVA_VERSION_OUTPUT" | while read -r l; do log_msg_to "  $l" "$GLOBAL"; done
            ;;
        Python)
            log_msg_to "🔍 Checking if 'python3' command exists..." "$GLOBAL"
            if ! command -v python3 >/dev/null 2>&1; then
                log_msg_to "❌ Python3 command not found in PATH." "$GLOBAL"
                exit 1
            fi

            log_msg_to "🔍 Checking if Python3 runs correctly..." "$GLOBAL"
            if ! PYTHON_VERSION_OUTPUT=$(python3 --version 2>&1); then
                log_msg_to "❌ Python3 exists but failed to run." "$GLOBAL"
                exit 1
            fi

            log_msg_to "✅ Python3 is installed: $PYTHON_VERSION_OUTPUT" "$GLOBAL"
            ;;
        NodeJS)
            log_msg_to "🔍 Checking if 'node' command exists..." "$GLOBAL"
            if ! command -v node >/dev/null 2>&1; then
                log_msg_to "❌ Node.js command not found in PATH." "$GLOBAL"
                exit 1
            fi
            log_msg_to "🔍 Checking if 'npm' command exists..." "$GLOBAL"
            if ! command -v npm >/dev/null 2>&1; then
                log_msg_to "❌ npm command not found in PATH." "$GLOBAL"
                exit 1
            fi

            log_msg_to "🔍 Checking if Node.js runs correctly..." "$GLOBAL"
            if ! NODE_VERSION_OUTPUT=$(node -v 2>&1); then
                log_msg_to "❌ Node.js exists but failed to run." "$GLOBAL"
                exit 1
            fi

            log_msg_to "🔍 Checking if npm runs correctly..." "$GLOBAL"
            if ! NPM_VERSION_OUTPUT=$(npm -v 2>&1); then
                log_msg_to "❌ npm exists but failed to run." "$GLOBAL"
                exit 1
            fi

            log_msg_to "✅ Node.js is installed: $NODE_VERSION_OUTPUT" "$GLOBAL"
            log_msg_to "✅ npm is installed: $NPM_VERSION_OUTPUT" "$GLOBAL"
            ;;
        *)
            log_msg_to "❌ Unknown tech stack selected: $TECH_STACK" "$GLOBAL"
            exit 1
            ;;
    esac

    log_msg_to "✅ Prerequisites validated for $TECH_STACK" "$GLOBAL"
}

# ===== Ask user for test URL via UI prompt =====
ask_user_for_test_url() {
  CX_TEST_URL=$(osascript -e 'Tell application "System Events" to display dialog "Enter the URL you want to test with BrowserStack:\n(Leave blank for default: '"$DEFAULT_TEST_URL"')" default answer "" with title "Test URL Setup" buttons {"OK"} default button "OK"' \
                  -e 'text returned of result')

  if [ -n "$CX_TEST_URL" ]; then
    log_msg_to "🌐 Using custom test URL: $CX_TEST_URL" "$PRE_RUN_LOG_FILE"
  else
    CX_TEST_URL="$DEFAULT_TEST_URL"
    log_msg_to "⚠️ No URL entered. Falling back to default: $CX_TEST_URL" "$PRE_RUN_LOG_FILE"
  fi
}

ask_and_upload_app() {
  APP_FILE_PATH=$(osascript -e 'POSIX path of (choose file with prompt "📱 Please select your .apk or .ipa app file to upload to BrowserStack, If No App Selected then Defualt Browserstack app will be used automatically")')

  if [ -z "$APP_FILE_PATH" ]; then
    log_msg_to "⚠️ No app selected. Using default sample app: bs://sample.app" "$GLOBAL"
    APP_URL="bs://sample.app"
    APP_PLATFORM="all"
    return
  fi

  # Detect platform
  if [[ "$APP_FILE_PATH" == *.apk ]]; then
    APP_PLATFORM="android"
  elif [[ "$APP_FILE_PATH" == *.ipa ]]; then
    APP_PLATFORM="ios"
  else
    log_msg_to "❌ Unsupported file type. Only .apk or .ipa allowed." "$GLOBAL"
    exit 1
  fi

  # Upload app
  log_msg_to "⬆️ Uploading $APP_FILE_PATH to BrowserStack..." "$GLOBAL"
  UPLOAD_RESPONSE=$(curl -s -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" \
    -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
    -F "file=@$APP_FILE_PATH")

  APP_URL=$(echo "$UPLOAD_RESPONSE" | grep -o '"app_url":"[^"]*' | cut -d'"' -f4)

  if [ -z "$APP_URL" ]; then
    log_msg_to "❌ Upload failed. Response: $UPLOAD_RESPONSE" "$GLOBAL"
    exit 1
  fi

  log_msg_to "✅ App uploaded successfully: $APP_URL" "$GLOBAL"
}

ask_test_type() {
    TEST_TYPE=$(osascript -e 'Tell application "System Events" to display dialog "Select testing type:" buttons {"Web", "App", "Both"} default button "Web" with title "Testing Type"' \
                          -e 'button returned of result')
    log_msg_to "✅ Selected Testing Type: $TEST_TYPE" "$GLOBAL"

    case "$TEST_TYPE" in
      "Web")
        ask_user_for_test_url
        ;;
      "App")
        ask_and_upload_app
        ;;
      "Both")
        ask_user_for_test_url
        ask_and_upload_app
        ;;
    esac
}


# ===== Dynamic config generators =====
generate_web_platforms_yaml() {
  local max_total_parallels=$1
  local max
  max=$(echo "$max_total_parallels * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  [ -z "$max" ] && max=0
  local yaml=""
  local count=0

  for template in "${WEB_PLATFORM_TEMPLATES[@]}"; do
    IFS="|" read -r os osVersion browserName <<< "$template"
    for version in latest latest-1 latest-2; do
      yaml+="  - os: $os
    osVersion: $osVersion
    browserName: $browserName
    browserVersion: $version
"
      count=$((count + 1))
      if [ "$count" -ge "$max" ]; then
        echo "$yaml"
        return
      fi
    done
  done

  echo "$yaml"
}


generate_mobile_platforms_yaml() {
  local max_total_parallels=$1
  local max=$(echo "$max_total_parallels * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)

  # fallback if bc result is empty or zero
  if [ -z "$max" ] || [ "$max" -lt 1 ]; then
    max=1
  fi

  local yaml=""
  local count=0

  for template in "${MOBILE_ALL[@]}"; do
    IFS="|" read -r platformName deviceName platformVersion <<< "$template"

    # Apply platform filter
    if [ -n "$APP_PLATFORM" ]; then
      if [[ "$APP_PLATFORM" == "ios" && "$platformName" != "ios" ]]; then
        continue
      fi
      if [[ "$APP_PLATFORM" == "android" && "$platformName" != "android" ]]; then
        continue
      fi
    fi

    yaml+="  - platformName: $platformName
    deviceName: $deviceName
    platformVersion: '${platformVersion}.0'
"
    count=$((count + 1))
    if [ "$count" -ge "$max" ]; then
      echo "$yaml"
      return
    fi
  done

  echo "$yaml"
}


generate_web_caps_json() {
  local max_total_parallels=$1
  local max
  max=$(echo "$max_total_parallels * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  [ "$max" -lt 1 ] && max=1  # fallback to minimum 1

  local json=""
  local count=0

  for template in "${WEB_PLATFORM_TEMPLATES[@]}"; do
    IFS="|" read -r os osVersion browserName <<< "$template"
    for version in latest latest-1 latest-2; do
      json+="{
        \"browserName\": \"$browserName\",
        \"browserVersion\": \"$version\",
        \"bstack:options\": {
          \"os\": \"$os\",
          \"osVersion\": \"$osVersion\"
        }
      },"
      count=$((count + 1))
      if [ "$count" -ge "$max" ]; then
        json="${json%,}"  # strip trailing comma
        echo "$json"
        return
      fi
    done
  done

  # Fallback in case not enough combinations
  json="${json%,}"
  echo "$json"
}

generate_mobile_caps_json() {
  local max_total=$1
  local count=0
  local usage_file="/tmp/device_usage.txt"
  : > "$usage_file"

  local json="["
  for template in "${MOBILE_DEVICE_TEMPLATES[@]}"; do
    IFS="|" read -r platformName deviceName baseVersion <<< "$template"
    local usage
    usage=$(grep -Fxc "$deviceName" "$usage_file")

    if [ "$usage" -ge 5 ]; then
      continue
    fi

    json="${json}{
      \"bstack:options\": {
        \"deviceName\": \"${deviceName}\",
        \"osVersion\": \"${baseVersion}.0\"
      }
    },"

    echo "$deviceName" >> "$usage_file"
    count=$((count + 1))
    if [ "$count" -ge "$max_total" ]; then
      break
    fi
  done

  json="${json%,}]"
  echo "$json"
  rm -f "$usage_file"
}

# ===== Fetch plan details (writes to GLOBAL) =====
fetch_plan_details() {
    log_msg_to "ℹ️ Fetching BrowserStack Plan Details..." "$GLOBAL"
    local web_unauthorized=false
    local mobile_unauthorized=false

    if [[ "$TEST_TYPE" == "Web" || "$TEST_TYPE" == "Both" ]]; then
        RESPONSE_WEB=$(curl -s -w "\n%{http_code}" -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" https://api.browserstack.com/automate/plan.json)
        HTTP_CODE_WEB=$(echo "$RESPONSE_WEB" | tail -n1)
        RESPONSE_WEB_BODY=$(echo "$RESPONSE_WEB" | sed '$d')
        if [ "$HTTP_CODE_WEB" == "200" ]; then
            WEB_PLAN_FETCHED=true
            TEAM_PARALLELS_MAX_ALLOWED_WEB=$(echo "$RESPONSE_WEB_BODY" | grep -o '"parallel_sessions_max_allowed":[0-9]*' | grep -o '[0-9]*')
            log_msg_to "✅ Web Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_WEB" "$GLOBAL"
        else
            log_msg_to "❌ Web Testing Plan fetch failed ($HTTP_CODE_WEB)" "$GLOBAL"
            [ "$HTTP_CODE_WEB" == "401" ] && web_unauthorized=true
        fi
    fi

    if [[ "$TEST_TYPE" == "App" || "$TEST_TYPE" == "Both" ]]; then
        RESPONSE_MOBILE=$(curl -s -w "\n%{http_code}" -u "$BROWSERSTACK_USERNAME:$BROWSERSTACK_ACCESS_KEY" https://api-cloud.browserstack.com/app-automate/plan.json)
        HTTP_CODE_MOBILE=$(echo "$RESPONSE_MOBILE" | tail -n1)
        RESPONSE_MOBILE_BODY=$(echo "$RESPONSE_MOBILE" | sed '$d')
        if [ "$HTTP_CODE_MOBILE" == "200" ]; then
            MOBILE_PLAN_FETCHED=true
            TEAM_PARALLELS_MAX_ALLOWED_MOBILE=$(echo "$RESPONSE_MOBILE_BODY" | grep -o '"parallel_sessions_max_allowed":[0-9]*' | grep -o '[0-9]*')
            log_msg_to "✅ Mobile App Testing Plan fetched: Team max parallel sessions = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE" "$GLOBAL"
        else
            log_msg_to "❌ Mobile App Testing Plan fetch failed ($HTTP_CODE_MOBILE)" "$GLOBAL"
            [ "$HTTP_CODE_MOBILE" == "401" ] && mobile_unauthorized=true
        fi
    fi

    if [[ "$TEST_TYPE" == "Web" && "$web_unauthorized" == true ]] || \
       [[ "$TEST_TYPE" == "App" && "$mobile_unauthorized" == true ]] || \
       [[ "$TEST_TYPE" == "Both" && "$web_unauthorized" == true && "$mobile_unauthorized" == true ]]; then
        log_msg_to "❌ Unauthorized to fetch required plan(s). Exiting." "$GLOBAL"
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
  export NOW_WEB_DOMAIN="$domain"

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


setup_web_java() {
  local local_flag=$1
  local parallels=$2

  REPO="now-testng-browserstack"
  TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"

  mkdir -p "$WORKSPACE_DIR/$PROJECT_FOLDER"

  # === 1️⃣ Clone Repo ===
  if [ ! -d "$TARGET_DIR" ]; then
    log_msg_to "📦 Cloning repo $REPO into $TARGET_DIR" "$GLOBAL" "$WEB_LOG_FILE"
    git clone https://github.com/browserstackCE/now-testng-browserstack.git "$TARGET_DIR" >> "$WEB_LOG_FILE" 2>&1 || true
  else
    log_msg_to "📂 Repo $REPO already exists at $TARGET_DIR, skipping clone." "$GLOBAL" "$WEB_LOG_FILE"
  fi

  cd "$TARGET_DIR" || return 1
  # validate_prereqs || return 1


  # === 3️⃣ Update Base URL ===
  if grep -qr "https://www.bstackdemo.com" .; then
    log_msg_to "🌐 Updating base URL to $CX_TEST_URL" "$GLOBAL" "$WEB_LOG_FILE"
    sed -i.bak "s|https://www.bstackdemo.com|$CX_TEST_URL|g" $(grep -rl "https://www.bstackdemo.com" .)
  fi

  if is_domain_private; then
    local_flag=true
  fi

  # === 4️⃣ Local Flag ===
  if [ "$local_flag" = "true" ]; then
    log_msg_to "✅ BrowserStack Local is ENABLED for this run." "$GLOBAL" "$WEB_LOG_FILE"
  else
    log_msg_to "✅ BrowserStack Local is DISABLED for this run." "$GLOBAL" "$WEB_LOG_FILE"
  fi

  # === 5️⃣ YAML Setup ===
  log_msg_to "🧩 Generating YAML config (bstack.yml)" "$GLOBAL" "$WEB_LOG_FILE"
  platform_yaml=$(generate_web_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_WEB")
  cat > browserstack.yml <<EOF
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: testng
browserstackLocal: $local_flag
buildName: now-testng-java-web
projectName: NOW-Web-Test
percy: true
accessibility: true
platforms:
$platform_yaml
parallelsPerPlatform: $parallels
EOF

  

  # === 6️⃣ Build and Run ===
  log_msg_to "⚙️ Running 'mvn install -DskipTests'" "$GLOBAL" "$WEB_LOG_FILE"
  mvn install -DskipTests >> "$WEB_LOG_FILE" 2>&1 || true

  log_msg_to "🚀 Running 'mvn test -P sample-test'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/" "$GLOBAL" "$WEB_LOG_FILE"
  mvn test -P sample-test >> "$WEB_LOG_FILE" 2>&1 &
  cmd_pid=$!|| true

  show_spinner "$cmd_pid"
  wait "$cmd_pid"

  cd "$WORKSPACE_DIR/$PROJECT_FOLDER"
  return 0
}

setup_web_python() {
  local local_flag=$1
  local parallels=$2
  local log_file=$3

  REPO="now-pytest-browserstack"
  TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"

  if [ ! -d "$TARGET_DIR" ]; then
    git clone https://github.com/browserstackCE/$REPO.git "$TARGET_DIR" >> "$WEB_LOG_FILE" 2>&1 || true
    log_msg_to "✅ Cloned repository: $REPO into $TARGET_DIR" "$PRE_RUN_LOG_FILE"
  else
    log_msg_to "ℹ️ Repository already exists at: $TARGET_DIR (skipping clone)"
  fi

  cd "$TARGET_DIR" || return 1

  #validate_prereqs || return 1

  # Setup Python venv
  if [ ! -d "venv" ]; then
    python3 -m venv venv
    log_msg_to "✅ Created Python virtual environment"
  fi
  
  # shellcheck disable=SC1091
  source venv/bin/activate
  pip3 install -r requirements.txt >> "$WEB_LOG_FILE" 2>&1

  # Export credentials for pytest to use
  export BROWSERSTACK_USERNAME="$BROWSERSTACK_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BROWSERSTACK_ACCESS_KEY"

  # Update YAML at root level (browserstack.yml)
  export BROWSERSTACK_CONFIG_FILE="browserstack.yml"
  platform_yaml=$(generate_web_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_WEB")

    if is_domain_private; then
    local_flag=true
  fi

    # === 4️⃣ Local Flag ===
  if [ "$local_flag" = "true" ]; then
    log_msg_to "✅ BrowserStack Local is ENABLED for this run." "$GLOBAL" "$WEB_LOG_FILE"
  else
    log_msg_to "✅ BrowserStack Local is DISABLED for this run." "$GLOBAL" "$WEB_LOG_FILE"
  fi

  cat > browserstack.yml <<EOF
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $local_flag
buildName: browserstack-sample-python-web
projectName: NOW-Web-Test
percy: true
accessibility: true
platforms:
$platform_yaml
parallelsPerPlatform: $parallels
EOF

  log_msg_to "✅ Updated root-level browserstack.yml with platforms and credentials."


  # Update base URL in the new sample test
  # sed -i.bak "s|https://bstackdemo.com/|$CX_TEST_URL|g" tests/bstack-sample-test.py || true
  sed -i.bak "s|https://bstackdemo.com|$CX_TEST_URL|g" tests/bstack-sample-test.py || true
  log_msg_to "🌐 Updated base URL in tests/bstack-sample-test.py to: $CX_TEST_URL"


  log_msg_to "🚀 Running 'browserstack-sdk pytest -s tests/bstack-sample-test.py'. This could take a few minutes. Follow the Automaton build here: https://automation.browserstack.com/" "$GLOBAL" "$WEB_LOG_FILE"
  # Run tests
  browserstack-sdk pytest -s tests/bstack-sample-test.py >> "$WEB_LOG_FILE" 2>&1 &
  cmd_pid=$!|| true

  show_spinner "$cmd_pid"
  wait "$cmd_pid"

  cd "$WORKSPACE_DIR/$PROJECT_FOLDER"
  return 0
}


setup_web_js() {
  local local_flag=$1
  local parallels=$2

  REPO="webdriverio-browserstack"
  TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"

  mkdir -p "$WORKSPACE_DIR/$PROJECT_FOLDER"

  # === 1️⃣ Clone Repo ===
  if [ ! -d "$TARGET_DIR" ]; then
    log_msg_to "📦 Cloning repo $REPO (branch tra) into $TARGET_DIR" "$GLOBAL" "$WEB_LOG_FILE"
    git clone -b tra https://github.com/browserstack/$REPO.git "$TARGET_DIR" >> "$WEB_LOG_FILE" 2>&1 || true
  else
    log_msg_to "📂 Repo $REPO already exists at $TARGET_DIR, skipping clone." "$GLOBAL" "$WEB_LOG_FILE"
  fi

  cd "$TARGET_DIR" || return 1
  validate_prereqs || return 1

  # === 2️⃣ Install Dependencies ===
  log_msg_to "⚙️ Running 'npm install'" "$GLOBAL" "$WEB_LOG_FILE"
  npm install >> "$WEB_LOG_FILE" 2>&1 || true


  # === 4️⃣ Generate Capabilities JSON ===
  log_msg_to "🧩 Generating browser/OS capabilities" "$GLOBAL" "$WEB_LOG_FILE"
  local caps_json
  caps_json=$(generate_web_caps_json "$parallels")

  # === 5️⃣ Determine buildIdentifier based on local ===
  if [ "$local_flag" = true ]; then
    BUILD_ID="#${BUILD_NUMBER}-local"
  else
    BUILD_ID="#${BUILD_NUMBER}-remote"
  fi

  cat > conf/base.conf.js <<EOF
exports.config = {
  user: process.env.BROWSERSTACK_USERNAME || 'BROWSERSTACK_USERNAME',
  key: process.env.BROWSERSTACK_ACCESS_KEY || 'BROWSERSTACK_ACCESS_KEY',

  updateJob: false,
  specs: ['./tests/specs/test.js'],
  exclude: [],

  logLevel: 'warn',
  coloredLogs: true,
  screenshotPath: './errorShots/',
  baseUrl: "$CX_TEST_URL",

   waitforTimeout: 10000,
  connectionRetryTimeout: 120000,
  connectionRetryCount: 1,
  hostname: 'hub.browserstack.com',
  services: [['browserstack']],

  before: function () {
    var chai = require('chai');
    global.expect = chai.expect;
    chai.Should();
  },

  framework: 'mocha',
  mochaOpts: {
    ui: 'bdd',
    timeout: 60000,
  },
};
EOF

cat > tests/specs/test.js <<EOF
describe("Testing with BStackDemo", () => {
  it("add product to cart", async () => {
    await browser.url("$CX_TEST_URL");

    await browser.waitUntil(
      async () => (await browser.getTitle()).match(/StackDemo/i),
      { timeout: 5000, timeoutMsg: "Title didn't match with BrowserStack" }
    );
    
    await browser.waitUntil(
      async () => (await productInCart.getText()).match(productOnScreenText),
      { timeout: 5000 }
    );
  });
});
EOF



 # === 6️⃣ Create conf/test.conf.js using template ===
log_msg_to "🛠️ Creating conf/test.conf.js configuration file" "$GLOBAL" "$WEB_LOG_FILE"

if [ "$local_flag" = true ]; then
  # BUILD_ID="#${BUILD_NUMBER}-localOn"
  cat > conf/test.conf.js <<EOF
const { config: baseConfig } = require('./base.conf.js');
const parallelConfig = {
  maxInstances: $parallels,
  commonCapabilities: {
    'bstack:options': {
      buildIdentifier: "$BUILD_ID",
      buildName: 'browserstack-sample-js-web',
      source: 'webdriverio:sample-master:v1.2',
      projectName: 'NOW-Web-Test',
    }
  },
  services: [
    [
      'browserstack',
      { 
        testObservability: true,
        testObservabilityOptions: {
          buildTag: ['bstack_sample']
        },
        browserstackLocal: true,
        accessibility: true,
        percy: true,
      },
    ],
  ],
  capabilities: [
$(echo "$caps_json" | sed 's/^/    /')
  ],
};
exports.config = { ...baseConfig, ...parallelConfig };
exports.config.capabilities.forEach(function (caps) {
  for (var i in exports.config.commonCapabilities)
    caps[i] = { ...caps[i], ...exports.config.commonCapabilities[i]};
});
EOF

else
  cat > conf/test.conf.js <<EOF
const { config: baseConfig } = require('./base.conf.js');
const parallelConfig = {
  maxInstances: $parallels,
  commonCapabilities: {
    'bstack:options': {
      buildIdentifier: "$BUILD_ID",
      buildName: 'browserstack-sample-js-web',
      source: 'webdriverio:sample-master:v1.2',
      projectName: 'NOW-Web-Test',
    }
  },
  services: [
    [
      'browserstack',
      { 
        testObservability: true,
        testObservabilityOptions: {
          buildTag: ['bstack_sample']
        },
        browserstackLocal: false,
        accessibility: true,
        percy: true,
      },
    ],
  ],
  capabilities: [
$(echo "$caps_json" | sed 's/^/    /')
  ],
};
exports.config = { ...baseConfig, ...parallelConfig };
exports.config.capabilities.forEach(function (caps) {
  for (var i in exports.config.commonCapabilities)
    caps[i] = { ...caps[i], ...exports.config.commonCapabilities[i]};
});
EOF

fi

  if is_domain_private; then
    local_flag=true
  fi

  # Log local flag status
  if [ "$local_flag" = "true" ]; then
    log_msg_to "✅ BrowserStack Local is ENABLED for this run." "$PRE_RUN_LOG_FILE"
  else
    log_msg_to "✅ BrowserStack Local is DISABLED for this run." "$PRE_RUN_LOG_FILE"
  fi  

  # === 7️⃣ Export BrowserStack Credentials ===
  export BROWSERSTACK_USERNAME="$BROWSERSTACK_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BROWSERSTACK_ACCESS_KEY"
  export BROWSERSTACK_LOCAL=$local_flag

  # === 8️⃣ Run Tests ===
  log_msg_to "🚀 Running 'npm run test'" "$GLOBAL" "$WEB_LOG_FILE"
  npm run test >> "$WEB_LOG_FILE" 2>&1 || true

  # === 9️⃣ Wrap Up ===
  log_msg_to "✅ Web JS setup and test execution completed successfully." "$GLOBAL" "$WEB_LOG_FILE"

  cd "$WORKSPACE_DIR/$PROJECT_FOLDER"
  return 0
}


# ===== Web wrapper with retry logic (writes runtime logs to WEB_LOG_FILE) =====
setup_web() {
  log_msg_to "Starting Web setup for $TECH_STACK" "$WEB_LOG_FILE"

  local local_flag=false
  local attempt=1
  local success=true
  local log_file=$WEB_LOG_FILE
  # don't pre-create; file will be created on first write by log_msg_to or command output redirection

  local total_parallels
  total_parallels=$(echo "$TEAM_PARALLELS_MAX_ALLOWED_WEB * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  [ -z "$total_parallels" ] && total_parallels=1
  local parallels_per_platform
  parallels_per_platform=$total_parallels


  while [ "$attempt" -le 1 ]; do
    log_msg_to "[Web Setup]" "$WEB_LOG_FILE"
    case "$TECH_STACK" in
      Java)       setup_web_java "$local_flag" "$parallels_per_platform" "$WEB_LOG_FILE" ;;
      Python)     setup_web_python "$local_flag" "$parallels_per_platform" "$WEB_LOG_FILE" ;;
      NodeJS) setup_web_js "$local_flag" "$parallels_per_platform" "$WEB_LOG_FILE" ;;
      *) log_msg_to "Unknown TECH_STACK: $TECH_STACK" "$WEB_LOG_FILE"; return 1 ;;
    esac

    if (grep -qiE "BUILD FAILURE" "$WEB_LOG_FILE"); then
      success=false
    fi

    if [ "$success" = true ]; then
      log_msg_to "✅ Web setup succeeded." "$WEB_LOG_FILE"
      break
    elif [ "$SETUP_FAILURE" = true ]; then
      log_msg_to "❌ Web test failed due to setup error. Check logs at: $WEB_LOG_FILE" "$WEB_LOG_FILE"
      break
    else
      log_msg_to "❌ Web setup ended without success; check $WEB_LOG_FILE for details" "$WEB_LOG_FILE"
      break
    fi
  done
}


setup_mobile_python() {
  local local_flag=$1
  local parallels=$2
  local log_file=$3

  REPO="pytest-appium-app-browserstack"
  TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"

  # Clone repo if not present
  if [ ! -d "$TARGET_DIR" ]; then
    git clone https://github.com/browserstack/$REPO.git "$TARGET_DIR"
    log_msg_to "✅ Cloned repository: $REPO into $TARGET_DIR" "$PRE_RUN_LOG_FILE"
  else
    log_msg_to "ℹ️ Repository already exists at: $TARGET_DIR (skipping clone)" "$PRE_RUN_LOG_FILE"
  fi

  cd "$TARGET_DIR" || return 1

  # Create & activate venv (if not exists)
  if [ ! -d "venv" ]; then
    python3 -m venv venv
  fi
  # shellcheck disable=SC1091
  source venv/bin/activate

  # Install dependencies
  pip install -r requirements.txt >> "$log_file" 2>&1

  # Export credentials
  export BROWSERSTACK_USERNAME="$BROWSERSTACK_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BROWSERSTACK_ACCESS_KEY"

  # Prepare platform-specific YAMLs in android/ and ios/
  local original_platform="$APP_PLATFORM"

  APP_PLATFORM="android"
  local platform_yaml_android
  platform_yaml_android=$(generate_mobile_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE")
  cat > android/browserstack.yml <<EOF
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $local_flag
buildName: browserstack-build-mobile
projectName: NOW-Mobile-Test
parallelsPerPlatform: $parallels
app: $APP_URL
platforms:
$platform_yaml_android
EOF

  APP_PLATFORM="ios"
  local platform_yaml_ios
  platform_yaml_ios=$(generate_mobile_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE")
  cat > ios/browserstack.yml <<EOF
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: pytest
browserstackLocal: $local_flag
buildName: browserstack-build-mobile
projectName: NOW-Mobile-Test
parallelsPerPlatform: $parallels
app: $APP_URL
platforms:
$platform_yaml_ios
EOF

  APP_PLATFORM="$original_platform"

  log_msg_to "✅ Wrote platform YAMLs to android/browserstack.yml and ios/browserstack.yml" "$PRE_RUN_LOG_FILE"

  # Replace sample tests in both android and ios with universal, locator-free test
  cat > android/bstack_sample.py <<'PYEOF'
import pytest


@pytest.mark.usefixtures('setWebdriver')
class TestUniversalAppCheck:

    def test_app_health_check(self):

        # 1. Get initial app and device state (no locators)
        initial_package = self.driver.current_package
        initial_activity = self.driver.current_activity
        initial_orientation = self.driver.orientation

        # 2. Log the captured data to BrowserStack using 'annotate'
        log_data = f"Initial State: Package='{initial_package}', Activity='{initial_activity}', Orientation='{initial_orientation}'"
        self.driver.execute_script(
            'browserstack_executor: {"action": "annotate", "arguments": {"data": "' + log_data + '", "level": "info"}}'
        )

        # 3. Perform a locator-free action: change device orientation
        self.driver.orientation = 'LANDSCAPE'

        # 4. Perform locator-free assertions
        assert self.driver.orientation == 'LANDSCAPE'

        # 5. Log the successful state change
        self.driver.execute_script(
            'browserstack_executor: {"action": "annotate", "arguments": {"data": "Successfully changed orientation to LANDSCAPE", "level": "info"}}'
        )
        
        # 6. Set the final session status to 'passed'
        self.driver.execute_script(
            'browserstack_executor: {"action": "setSessionStatus", "arguments": {"status": "passed", "reason": "App state verified and orientation changed!"}}'
        )
PYEOF

  cp android/bstack_sample.py ios/bstack_sample.py

  # Decide which directory to run based on APP_PLATFORM (default to android)
  local run_dir="android"
  if [ "$APP_PLATFORM" = "ios" ]; then
    run_dir="ios"
  fi

  if is_domain_private; then
    local_flag=true
  fi

  # Log local flag status
  if [ "$local_flag" = "true" ]; then
    log_msg_to "⚠️ BrowserStack Local is ENABLED for this run." "$PRE_RUN_LOG_FILE"
  else
    log_msg_to "⚠️ BrowserStack Local is DISABLED for this run." "$PRE_RUN_LOG_FILE"
  fi  

  # Run pytest with BrowserStack SDK from the chosen platform directory
  log_msg_to "🚀 Running 'cd $run_dir && browserstack-sdk pytest -s bstack_sample.py'" "$PRE_RUN_LOG_FILE"
  (
    cd "$run_dir" && browserstack-sdk pytest -s bstack_sample.py >> "$log_file" 2>&1 || true
  )

  # Copy first 200 lines of logs for visibility
  [ -f "$log_file" ] && sed -n '1,200p' "$log_file" | while read -r l; do 
    log_msg_to "mobile (python): $l" "$PRE_RUN_LOG_FILE"
  done

  deactivate
  cd "$WORKSPACE_DIR/$PROJECT_FOLDER"
  return 0
}


setup_mobile_java() {
  local local_flag=$1
  local parallels=$2
  local log_file=$3

  REPO="browserstack-examples-appium-testng"
  TARGET_DIR="$WORKSPACE_DIR/$PROJECT_FOLDER/$REPO"

  if [ ! -d "$TARGET_DIR" ]; then
    git clone https://github.com/BrowserStackCE/$REPO.git "$TARGET_DIR"
    log_msg_to "✅ Cloned repository: $REPO into $TARGET_DIR" "$GLOBAL" "$MOBILE_LOG_FILE"
  else
    log_msg_to "ℹ️ Repository already exists at: $TARGET_DIR (skipping clone)" "$GLOBAL" "$MOBILE_LOG_FILE"
  fi

  # Update pom.xml → browserstack-java-sdk version to LATEST
  pom_file="$TARGET_DIR/pom.xml"
  if [ -f "$pom_file" ]; then
    sed -i.bak '/<artifactId>browserstack-java-sdk<\/artifactId>/,/<\/dependency>/ s|<version>.*</version>|<version>LATEST</version>|' "$pom_file"
    log_msg_to "🔧 Updated browserstack-java-sdk version to LATEST in pom.xml" "$GLOBAL" "$MOBILE_LOG_FILE"
  fi

  cd "$TARGET_DIR" || return 1
  validate_prereqs || return 1

  # Export credentials for Maven
  export BROWSERSTACK_USERNAME="$BROWSERSTACK_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BROWSERSTACK_ACCESS_KEY"

  # Update TestBase.java → switch AppiumDriver to AndroidDriver
  testbase_file=$(find src -name "TestBase.java" | head -n 1)
  if [ -f "$testbase_file" ]; then
    sed -i.bak 's/new AppiumDriver(/new AndroidDriver(/g' "$testbase_file"
    log_msg_to "🔧 Updated driver initialization in $testbase_file to use AndroidDriver" "$GLOBAL" "$MOBILE_LOG_FILE"
  fi

  # YAML config path
  export BROWSERSTACK_CONFIG_FILE="src/test/resources/conf/capabilities/browserstack-parallel.yml"
  platform_yaml=$(generate_mobile_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE")

  cat > "$BROWSERSTACK_CONFIG_FILE" <<EOF
userName: $BROWSERSTACK_USERNAME
accessKey: $BROWSERSTACK_ACCESS_KEY
framework: testng
browserstackLocal: $local_flag
buildName: browserstack-build-mobile
projectName: NOW-Mobile-Test
parallelsPerPlatform: $parallels
accessibility: true
percy: true
app: $APP_URL
platforms:
$platform_yaml
EOF

  log_msg_to "✅ Updated $BROWSERSTACK_CONFIG_FILE with platforms and credentials" "$GLOBAL" "$MOBILE_LOG_FILE"

cat > "/src/test/java/com/browserstack/test/suites/e2e/OrderTest.java" <<EOF
package com.browserstack.test.suites.e2e;

import com.browserstack.app.pages.HomePage;
import com.browserstack.app.pages.OrdersPage;
import com.browserstack.test.suites.TestBase;
import org.testng.Assert;
import org.testng.annotations.Test;

public class OrderTest extends TestBase {

    @Test
    public void placeOrder() {
        HomePage page = new HomePage(driver)
                .navigateToSignIn()
                .loginWith("fav_user", "testingisfun99");
               
    }
}
EOF

  if is_domain_private; then
    local_flag=true
  fi

  # Log local flag status
  if [ "$local_flag" = "true" ]; then
    log_msg_to "✅ BrowserStack Local is ENABLED for this run." "$GLOBAL" "$MOBILE_LOG_FILE"
  else
    log_msg_to "✅ BrowserStack Local is DISABLED for this run." "$GLOBAL" "$MOBILE_LOG_FILE"
  fi  

  # Run Maven install first
  log_msg_to "⚙️ Running 'mvn install -DskipTests'" "$GLOBAL" "$MOBILE_LOG_FILE"
  mvn install -DskipTests >> "$log_file" 2>&1 || true

  # Then run actual test suite
  log_msg_to "🚀 Running 'mvn clean test -P bstack-parallel -Dtest=OrderTest'" "$GLOBAL" "$MOBILE_LOG_FILE"
  mvn clean test -P bstack-parallel -Dtest=OrderTest >> "$log_file" 2>&1 || true

  # Copy first 200 lines of logs for visibility
  [ -f "$log_file" ] && sed -n '1,200p' "$log_file" | while read -r l; do 
    log_msg_to "mobile (java): $l" "$GLOBAL" "$MOBILE_LOG_FILE"
  done

  cd "$WORKSPACE_DIR/$PROJECT_FOLDER"
  return 0
}


setup_mobile_js() {
  local local_flag=$1
  local parallels=$2
  local log_file=$3

  REPO="webdriverio-appium-app-browserstack"
  if [ ! -d "$REPO" ]; then
    git clone -b sdk https://github.com/browserstack/$REPO
  fi
  cd "$REPO/android/" || return 1

  validate_prereqs || return 1
  npm install >> "$log_file" 2>&1 || true
  cd "examples/run-parallel-test" || return 1
  caps_file="parallel.conf.js"

  if sed --version >/dev/null 2>&1; then
    sed -i "s/\(maxInstances:\)[[:space:]]*[0-9]\+/\1 $parallels/" "$caps_file" || true
  else
    sed -i '' "s/\(maxInstances:\)[[:space:]]*[0-9]\+/\1 $parallels/" "$caps_file" || true
  fi

  caps_json=$(generate_mobile_caps_json "$parallels")
  printf "%s\n" "capabilities: $caps_json," > "$caps_file".tmp || true
  mv "$caps_file".tmp "$caps_file" || true

  export BROWSERSTACK_USERNAME="$BROWSERSTACK_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BROWSERSTACK_ACCESS_KEY"

  npm run parallel > "$log_file" 2>&1 || true
  [ -f "$log_file" ] && sed -n '1,200p' "$log_file" | while read -r l; do log_msg_to "mobile: $l" "$GLOBAL"; done
  return 0
}

# ===== Mobile wrapper with retry logic (writes runtime logs to MOBILE_LOG_FILE) =====
setup_mobile() {
  log_msg_to "Starting Mobile setup for $TECH_STACK" "$MOBILE_LOG_FILE"

  local local_flag=true
  local attempt=1
  local success=false
  local log_file="$MOBILE_LOG_FILE"

  local total_parallels
  total_parallels=$(echo "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  [ -z "$total_parallels" ] && total_parallels=1
  local parallels_per_platform
  # parallels_per_platform=$(( (total_parallels + 2) / 3 ))
  parallels_per_platform=$total_parallels

  while [ "$attempt" -le 1 ]; do
    log_msg_to "[Mobile Setup Attempt $attempt] browserstackLocal: $local_flag" "$MOBILE_LOG_FILE"
    case "$TECH_STACK" in
      Java)       setup_mobile_java "$local_flag" "$parallels_per_platform" "$MOBILE_LOG_FILE" ;;
      Python)     setup_mobile_python "$local_flag" "$parallels_per_platform" "$MOBILE_LOG_FILE" ;;
      NodeJS) setup_mobile_js "$local_flag" "$parallels_per_platform" "$MOBILE_LOG_FILE" ;;
      *) log_msg_to "Unknown TECH_STACK: $TECH_STACK" "$MOBILE_LOG_FILE"; return 1 ;;
    esac

    LOG_CONTENT=$(<"$MOBILE_LOG_FILE" 2>/dev/null || true)
    LOCAL_FAILURE=false
    SETUP_FAILURE=false

    for pattern in "${MOBILE_LOCAL_ERRORS[@]}"; do
      echo "$LOG_CONTENT" | grep -qiE "$pattern" && LOCAL_FAILURE=true && break
    done

    for pattern in "${MOBILE_SETUP_ERRORS[@]}"; do
      echo "$LOG_CONTENT" | grep -qiE "$pattern" && SETUP_FAILURE=true && break
    done

    if echo "$LOG_CONTENT" | grep -qiE "https://[a-zA-Z0-9./?=_-]*browserstack\.com"; then
      success=true
    fi

    if [ "$success" = true ]; then
      log_msg_to "✅ Mobile setup succeeded" "$MOBILE_LOG_FILE"
      break
    elif [ "$LOCAL_FAILURE" = true ] && [ "$attempt" -eq 1 ]; then
      local_flag=false
      attempt=$((attempt + 1))
      log_msg_to "⚠️ Mobile test failed due to Local tunnel error. Retrying without browserstackLocal..." "$MOBILE_LOG_FILE"
    elif [ "$SETUP_FAILURE" = true ]; then
      log_msg_to "❌ Mobile test failed due to setup error. Check logs at: $log_file" "$MOBILE_LOG_FILE"
      break
    else
      log_msg_to "❌ Mobile setup ended without success; check $MOBILE_LOG_FILE for details" "$MOBILE_LOG_FILE"
      break
    fi
  done
}

# ===== Orchestration: decide what to run based on TEST_TYPE and plan fetch =====
run_setup() {
  log_msg_to "Orchestration: TEST_TYPE=$TEST_TYPE, WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED, MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED" "$GLOBAL"

  case "$TEST_TYPE" in
    Web)
      if [ "$WEB_PLAN_FETCHED" == true ]; then
        setup_web
      else
        log_msg_to "⚠️ Skipping Web setup — Web plan not fetched" "$GLOBAL"
      fi
      ;;
    App)
      if [ "$MOBILE_PLAN_FETCHED" == true ]; then
        setup_mobile
      else
        log_msg_to "⚠️ Skipping Mobile setup — Mobile plan not fetched" "$GLOBAL"
      fi
      ;;
    Both)
      local ran_any=false
      if [ "$WEB_PLAN_FETCHED" == true ]; then
        setup_web
        ran_any=true
      else
        log_msg_to "⚠️ Skipping Web setup — Web plan not fetched" "$GLOBAL"
      fi
      if [ "$MOBILE_PLAN_FETCHED" == true ]; then
        setup_mobile
        ran_any=true
      else
        log_msg_to "⚠️ Skipping Mobile setup — Mobile plan not fetched" "$GLOBAL"
      fi
      if [ "$ran_any" == false ]; then
        log_msg_to "❌ Both Web and Mobile setup were skipped. Exiting." "$GLOBAL"
        exit 1
      fi
      ;;
    *)
      log_msg_to "❌ Invalid TEST_TYPE: $TEST_TYPE" "$GLOBAL"
      exit 1
      ;;
  esac
}

# ===== Main flow (baseline steps then run) =====
setup_workspace
ask_browserstack_credentials
ask_test_type
ask_tech_stack
validate_tech_stack_installed
# ask_user_for_test_url
fetch_plan_details

# Plan summary in pre-run log
log_msg_to "Plan summary: WEB_PLAN_FETCHED=$WEB_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_WEB), MOBILE_PLAN_FETCHED=$MOBILE_PLAN_FETCHED (team max=$TEAM_PARALLELS_MAX_ALLOWED_MOBILE)" "$GLOBAL"

run_setup

log_msg_to "Setup run finished." "$GLOBAL"