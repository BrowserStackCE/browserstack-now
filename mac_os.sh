#!/bin/bash

# Define colors and symbols
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color
TICK="${GREEN}✅${NC}"
CROSS="${RED}❌${NC}"

SHOW_LOGS=false
if [[ "$1" == "--zlogs" ]]; then
  SHOW_LOGS=true
fi



BSS_ROOT="$HOME/.browserstack"
BSS_SETUP_DIR="$BSS_ROOT/browserstackSampleSetup"
LOG_FILE="$BSS_SETUP_DIR/bstackOnboardingLogs.log"
> "$LOG_FILE"  # Clear previous logs



log() {
  local message="$1"
  local timestamp
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo -e "[$timestamp] $message" >> "$LOG_FILE"
}


print_checker() {
  echo -e "$1"
}


PARALLEL_PERCENTAGE=1.00


#############################################
# Step 1: Workspace Setup
#############################################
setup_workspace() {
  mkdir -p "$BSS_SETUP_DIR" && print_checker "$TICK Setup directory ensured at $BSS_SETUP_DIR"
  cd "$BSS_SETUP_DIR" || { print_checker "$CROSS Failed to navigate to setup directory"; exit 1; }
  : > "$LOG_FILE"
  log "[Workspace initialized]"
}

#############################################
# Step 2: Prompt for BrowserStack Credentials
#############################################
prompt_credentials() {
  BS_USERNAME=$(osascript -e 'Tell application "System Events" to display dialog "Enter your BrowserStack Username:" default answer "" with title "BrowserStack Setup" buttons {"OK"} default button "OK"' -e 'text returned of result')
  if [ -z "$BS_USERNAME" ]; then
    print_checker "$CROSS Username empty"
    exit 1
  fi

  BS_ACCESS_KEY=$(osascript -e 'Tell application "System Events" to display dialog "Enter your BrowserStack Access Key:" default answer "" with hidden answer with title "BrowserStack Setup" buttons {"OK"} default button "OK"' -e 'text returned of result')
  if [ -z "$BS_ACCESS_KEY" ]; then
    print_checker "$CROSS Access Key empty"
    exit 1
  fi

  log "[Credentials entered]"
}

#############################################
# Step 3: Prompt for Test Type and Tech Stack
#############################################
# prompt_test_options() {
#   TEST_OPTION=$(osascript -e 'Tell application "System Events" to choose from list {"Web Testing", "Mobile App Testing", "Both"} with prompt "Select testing type:" default items "Web Testing"')
#   [ "$TEST_OPTION" == "false" ] && print_checker "$CROSS No test option selected" && exit 1
#   TEST_OPTION=$(echo "$TEST_OPTION" | sed 's/^[{(]*//;s/[})]*$//')

#   TECH_STACK=$(osascript -e 'Tell application "System Events" to choose from list {"Java", "Python", "JavaScript"} with prompt "Select your tech stack:" default items "Java"')
#   [ "$TECH_STACK" == "false" ] && print_checker "$CROSS No tech stack selected" && exit 1
#   TECH_STACK=$(echo "$TECH_STACK" | sed 's/^[{(]*//;s/[})]*$//')

#   log "[User selected: $TEST_OPTION | $TECH_STACK]"
# }


prompt_test_options() {
  TEST_OPTION=$(osascript -e 'Tell application "System Events" to choose from list {"Web Testing", "Mobile App Testing", "Both"} with prompt "Select testing type:" default items "Web Testing"')
  [ "$TEST_OPTION" == "false" ] && print_checker "$CROSS No test option selected" && exit 1
  TEST_OPTION=$(echo "$TEST_OPTION" | sed 's/^[{(]*//;s/[})]*$//')

  if [ "$TEST_OPTION" == "Mobile App Testing" ]; then
    TECH_STACK=$(osascript -e 'Tell application "System Events" to choose from list {"Java", "Python"} with prompt "Select your tech stack (Mobile supports Java & Python only):" default items "Java"')
  else
    TECH_STACK=$(osascript -e 'Tell application "System Events" to choose from list {"Java", "Python", "JavaScript"} with prompt "Select your tech stack:" default items "Java"')
  fi

  [ "$TECH_STACK" == "false" ] && print_checker "$CROSS No tech stack selected" && exit 1
  TECH_STACK=$(echo "$TECH_STACK" | sed 's/^[{(]*//;s/[})]*$//')

  log "[User selected: $TEST_OPTION | $TECH_STACK]"
}

#############################################
# Step 4: Validate Required Tools
#############################################
#############################################
# Prerequisite Validation (strict blocking)
#############################################
validate_prereqs() {
  print_checker "$INFO Checking prerequisites for $TECH_STACK..."
  print_checker "📂 Checking in current working directory: $(pwd)"

  case "$TECH_STACK" in
    Java)
      if ! command -v java >/dev/null 2>&1; then
        print_checker "$CROSS Java is not installed or not available in this environment.\n❗ Please ensure Java is installed and accessible in your PATH."
        exit 1
      fi
      JAVA_VERSION=$(java -version 2>&1)
      print_checker "$TICK Java is installed. Version details:\n$JAVA_VERSION"
      ;;
      
    Python)
      if ! command -v python3 >/dev/null 2>&1; then
        print_checker "$CROSS Python3 is not installed or not available in this environment.\n❗ Please ensure Python3 is installed and accessible in your PATH."
        exit 1
      fi
      PYTHON_VERSION=$(python3 --version 2>&1)
      print_checker "$TICK Python3 is installed: $PYTHON_VERSION"
      ;;
      
    JavaScript)
      if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
        print_checker "$CROSS Node.js or npm is not installed or not available in this environment.\n❗ Please ensure both Node.js and npm are installed and accessible in your PATH."
        exit 1
      fi
      NODE_VERSION=$(node -v)
      NPM_VERSION=$(npm -v)
      print_checker "$TICK Node.js is installed: $NODE_VERSION"
      print_checker "$TICK npm is installed: $NPM_VERSION"
      ;;
  esac

  print_checker "$TICK prerequisites validated for $TECH_STACK"
}




#############################################
# Step 5: Fetch Plan Details
#############################################
 fetch_plan_details() {
  log "[Fetching Plan Details]"

  WEB_PLAN_FETCHED=false
  MOBILE_PLAN_FETCHED=false

  web_unauthorized=false
  mobile_unauthorized=false

  if [[ "$TEST_OPTION" == "Web Testing" || "$TEST_OPTION" == "Both" ]]; then
    RESPONSE_WEB=$(curl -s -w "\n%{http_code}" -u "$BS_USERNAME:$BS_ACCESS_KEY" https://api.browserstack.com/automate/plan.json)
    HTTP_CODE_WEB=$(echo "$RESPONSE_WEB" | tail -n1)
    RESPONSE_WEB_BODY=$(echo "$RESPONSE_WEB" | sed '$d')

    if [ "$HTTP_CODE_WEB" == "200" ]; then
      WEB_PLAN_FETCHED=true
      TEAM_PARALLELS_MAX_ALLOWED_WEB=$(echo "$RESPONSE_WEB_BODY" | grep -o '"parallel_sessions_max_allowed":[0-9]*' | grep -o '[0-9]*')
      log "$RESPONSE_WEB_BODY"
      print_checker "$TICK Web Testing Plan fetched: Max Parallels = $TEAM_PARALLELS_MAX_ALLOWED_WEB"
    else
      log "$RESPONSE_WEB_BODY"
      print_checker "$CROSS Web Testing Plan fetch failed ($HTTP_CODE_WEB)"
      if [ "$HTTP_CODE_WEB" == "401" ]; then
        print_checker "${RED}⚠️ Check your credentials or Web Testing access.${NC}"
        web_unauthorized=true
      fi
    fi
  fi

  if [[ "$TEST_OPTION" == "Mobile App Testing" || "$TEST_OPTION" == "Both" ]]; then
    RESPONSE_MOBILE=$(curl -s -w "\n%{http_code}" -u "$BS_USERNAME:$BS_ACCESS_KEY" https://api-cloud.browserstack.com/app-automate/plan.json)
    HTTP_CODE_MOBILE=$(echo "$RESPONSE_MOBILE" | tail -n1)
    RESPONSE_MOBILE_BODY=$(echo "$RESPONSE_MOBILE" | sed '$d')

    if [ "$HTTP_CODE_MOBILE" == "200" ]; then
      MOBILE_PLAN_FETCHED=true
      TEAM_PARALLELS_MAX_ALLOWED_MOBILE=$(echo "$RESPONSE_MOBILE_BODY" | grep -o '"parallel_sessions_max_allowed":[0-9]*' | grep -o '[0-9]*')
      log "$RESPONSE_MOBILE_BODY"
      print_checker "$TICK Mobile App Testing Plan fetched: Max Parallels = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE"
    else
      log "$RESPONSE_MOBILE_BODY"
      print_checker "$CROSS Mobile App Testing Plan fetch failed ($HTTP_CODE_MOBILE)"
      if [ "$HTTP_CODE_MOBILE" == "401" ]; then
        print_checker "${RED}⚠️ Check your credentials or Mobile Testing access.${NC}"
        mobile_unauthorized=true
      fi
    fi
  fi

  # Exit Logic
  if [[ "$TEST_OPTION" == "Web Testing" && "$web_unauthorized" == true ]]; then
    exit 1
  elif [[ "$TEST_OPTION" == "Mobile App Testing" && "$mobile_unauthorized" == true ]]; then
    exit 1
  elif [[ "$TEST_OPTION" == "Both" && "$web_unauthorized" == true && "$mobile_unauthorized" == true ]]; then
    exit 1
  fi
}




PARALLEL_PERCENTAGE=1.00

#############################################
# Predefined Platform Templates
#############################################

WEB_PLATFORM_TEMPLATES=(
  "Windows|10|Chrome"
  "Windows|10|Firefox"
  "Windows|11|Edge"
  "Windows|11|Chrome"
  "Windows|8|Chrome"
  "OS X|Monterey|Safari"
  "OS X|Monterey|Chrome"
  "OS X|Ventura|Chrome"
  "OS X|Big Sur|Safari"
  "OS X|Catalina|Firefox"
)

MOBILE_DEVICE_TEMPLATES=(
  # Samsung
  "android|Samsung Galaxy S21|11"
  "android|Samsung Galaxy S25|15"
  "android|Samsung Galaxy S24|14"
  "android|Samsung Galaxy S22|12"
  "android|Samsung Galaxy S23|13"
  "android|Samsung Galaxy S21|12"
  "android|Samsung Galaxy Tab S10 Plus|15"
  "android|Samsung Galaxy S22 Ultra|12"
  "android|Samsung Galaxy S21 Ultra|11"
  "android|Samsung Galaxy S20|10"
  "android|Samsung Galaxy M32|11"
  "android|Samsung Galaxy Note 20|10"
  "android|Samsung Galaxy S10|9"
  "android|Samsung Galaxy Note 9|8"
  "android|Samsung Galaxy S9|8"
  "android|Samsung Galaxy Tab S8|12"
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
  "android|Samsung Galaxy S8|7"
  "android|Samsung Galaxy Tab A9 Plus|14"
  "android|Samsung Galaxy Tab S9|13"
  "android|Samsung Galaxy Tab S7|10"
  "android|Samsung Galaxy Tab S7|11"
  "android|Samsung Galaxy Tab S6|9"

  # Google Pixel
  "android|Google Pixel 9|15"
  "android|Google Pixel 6 Pro|13"
  "android|Google Pixel 8|14"
  "android|Google Pixel 7|13"
  "android|Google Pixel 6|12"
  "android|Google Pixel 3|9"
  "android|Google Pixel 9|16"
  "android|Google Pixel 6 Pro|12"
  "android|Google Pixel 6 Pro|15"
  "android|Google Pixel 9 Pro XL|15"
  "android|Google Pixel 9 Pro|15"
  "android|Google Pixel 8 Pro|14"
  "android|Google Pixel 7 Pro|13"
  "android|Google Pixel 5|11"
  "android|Google Pixel 5|12"
  "android|Google Pixel 4 XL|10"

  # Vivo
  "android|Vivo Y21|11"
  "android|Vivo Y50|10"
  "android|Vivo V30|14"
  "android|Vivo V21|11"

  # Oppo
  "android|Oppo Reno 6|11"
  "android|Oppo Reno 8T 5G|13"
  "android|Oppo A96|11"
  "android|Oppo Reno 3 Pro|10"

  # Realme
  "android|Realme 8|11"

  # Motorola
  "android|Motorola Moto G71 5G|11"
  "android|Motorola Moto G9 Play|10"
  "android|Motorola Moto G7 Play|9"

  # OnePlus
  "android|OnePlus 12R|14"
  "android|OnePlus 11R|13"
  "android|OnePlus 9|11"
  "android|OnePlus 8|10"

  # Xiaomi
  "android|Xiaomi Redmi Note 13 Pro 5G|14"
  "android|Xiaomi Redmi Note 12 4G|13"
  "android|Xiaomi Redmi Note 11|11"
  "android|Xiaomi Redmi Note 9|10"
  "android|Xiaomi Redmi Note 8|9"

  # Huawei
  "android|Huawei P30|9"
)



#############################################
# Dynamic YAML Generators with Permutations
#############################################

generate_web_platforms_yaml() {
  local max_total_parallels=$1
  local max=$(echo "$max_total_parallels * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
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
  local yaml=""
  local count=0

  for template in "${MOBILE_DEVICE_TEMPLATES[@]}"; do
    IFS="|" read -r platformName deviceName platformVersion <<< "$template"
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
  local max=$(echo "$max_total_parallels * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
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
  local max_total_parallels=$1
  local max=$(echo "$max_total_parallels * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  local json=""
  local count=0

  for template in "${MOBILE_DEVICE_TEMPLATES[@]}"; do
    IFS="|" read -r _ deviceName baseVersion <<< "$template"
    for delta in 0 -1; do
      version=$(echo "$baseVersion + $delta" | bc)
      json+="{
        \"device\": \"$deviceName\",
        \"os_version\": \"$version.0\"
      },"
      count=$((count + 1))
      if [ "$count" -ge "$max" ]; then
        json="${json%,}"
        echo "$json"
        return
      fi
    done
  done

  json="${json%,}"
  echo "$json"
}


#############################################
# Step 6: Setup Web with retry on Local true
#############################################

# Web Errors
WEB_SETUP_ERRORS=("Error" "Build failed" "Session not created" "Cannot start test")
WEB_LOCAL_ERRORS=("Execution of" "browserstack local failed" "fail local testing" "failed to connect tunnel")

setup_web_java() {
  local_flag=$1
  parallels=$2
  log_file=$3

  REPO="testng-browserstack"
  [ ! -d "$REPO" ] && git clone https://github.com/browserstack/$REPO
  cd "$REPO" || return

  validate_prereqs || return 1
  platform_yaml=$(generate_web_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_WEB")

  cat > browserstack.yml <<EOF
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: testng
browserstackLocal: $local_flag
buildName: browserstack-build-web
projectName: BrowserStack Web Sample
percy: true
accessibility: true
platforms:
$platform_yaml
EOF

  mvn test -P sample-test > "$log_file" 2>&1
  cat "$log_file" >> "$LOG_FILE"
}

setup_web_python() {
  local_flag=$1
  parallels=$2
  log_file=$3

  REPO="python-selenium-browserstack"
  [ ! -d "$REPO" ] && git clone https://github.com/browserstack/$REPO
  cd "$REPO" || return

  validate_prereqs || return 1
  python3 -m venv env && source env/bin/activate
  pip3 install -r requirements.txt >> "$LOG_FILE" 2>&1
  platform_yaml=$(generate_web_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_WEB")

  cat > browserstack.yml <<EOF
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: python
browserstackLocal: $local_flag
buildName: browserstack-build-web
projectName: BrowserStack Web Sample
platforms:
$platform_yaml
EOF

  browserstack-sdk python ./tests/test.py > "$log_file" 2>&1
  cat "$log_file" >> "$LOG_FILE"
}



setup_web_js() {
  local_flag=$1
  parallels=$2
  log_file=$3

  REPO="webdriverio-browserstack"
  [ ! -d "$REPO" ] && git clone https://github.com/browserstack/$REPO
  cd "$REPO" || return

  validate_prereqs || return 1
  npm install >> "$LOG_FILE" 2>&1

  local caps_file
  if [ "$local_flag" = true ]; then
    caps_file="conf/local-test.conf.js"

    # Insert maxInstances + commonCapabilities after 'const localConfig = {'
   perl -i -pe "s|const localConfig = \{\n|const localConfig = {\n  maxInstances: $TEAM_PARALLELS_MAX_ALLOWED_WEB,\n  commonCapabilities: {\n    'bstack:options': {\n      projectName: 'webdriverio-browserstack',\n      buildName: 'browserstack build',\n      buildIdentifier: '#\${BUILD_NUMBER}',\n      source: 'webdriverio:sample-master:v1.2'\n    }\n  },\n|;" "$caps_file"

    echo "exports.config.capabilities.forEach(function (caps) {" >> "$caps_file"
    echo "  for (var i in exports.config.commonCapabilities)" >> "$caps_file"
    echo "    caps[i] = { ...caps[i], ...exports.config.commonCapabilities[i]};" >> "$caps_file"
    echo "});" >> "$caps_file"

  else
    caps_file="conf/test.conf.js"

    # Replace maxInstances normally
    sed -i '' "s/\(maxInstances:\)[[:space:]]*[0-9]\+/\1 $TEAM_PARALLELS_MAX_ALLOWED_WEB/" "$caps_file"
  fi

  # Generate capabilities
  local caps_json caps_js
  caps_json=$(generate_web_caps_json "$TEAM_PARALLELS_MAX_ALLOWED_WEB")
  caps_js="[${caps_json}]"

  # Replace capabilities: [ ... ] block (multiline safe)
  perl -0777 -i -pe "s/capabilities:\s*\[(.*?)\]/capabilities: $caps_js/s" "$caps_file"

  export BROWSERSTACK_USERNAME="$BS_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BS_ACCESS_KEY"
  export BROWSERSTACK_LOCAL=$local_flag

  if [ "$local_flag" = true ]; then
    npm run local > "$log_file" 2>&1
  else
    npm run test > "$log_file" 2>&1
  fi

  cat "$log_file" >> "$LOG_FILE"
}





setup_web() {
  log "\n${BOLD}${BLUE}[Starting Web Setup for $TECH_STACK]${NC}"
  local local_flag=true
  local attempt=1
  local success=false
   local run_result_log="$BSS_SETUP_DIR/web_run_result.log"
  mkdir -p "$(dirname "$run_result_log")"
  local run_result_log_path
  run_result_log_path="$(realpath "$run_result_log")"
  rm -f "$run_result_log"

  total_parallels=$(echo "$TEAM_PARALLELS_MAX_ALLOWED_WEB * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  parallels_per_platform=$(( (total_parallels + 1) / 2 ))

  while [ "$attempt" -le 2 ]; do
    if [ "$SHOW_LOGS" = false ]; then
      echo -e "\n${YELLOW}[⏳ Please hold on while we prepare the next step in the background...]${NC}"
    fi

    log "[Web Setup Attempt $attempt] browserstackLocal: $local_flag"

    case "$TECH_STACK" in
      Java)       setup_web_java "$local_flag" "$parallels_per_platform" "$run_result_log" ;;
      Python)     setup_web_python "$local_flag" "$parallels_per_platform" "$run_result_log" ;;
      JavaScript) setup_web_js "$local_flag" "$parallels_per_platform" "$run_result_log" ;;
    esac

    LOG_CONTENT=$(<"$run_result_log")
    LOCAL_FAILURE=false
    SETUP_FAILURE=false

    for pattern in "${WEB_LOCAL_ERRORS[@]}"; do
      echo "$LOG_CONTENT" | grep -qiE "$pattern" && LOCAL_FAILURE=true && break
    done

    for pattern in "${WEB_SETUP_ERRORS[@]}"; do
      echo "$LOG_CONTENT" | grep -qiE "$pattern" && SETUP_FAILURE=true && break
    done

    if echo "$LOG_CONTENT" | grep -qiE "https://[a-zA-Z0-9./?=_-]*browserstack\.com"; then
      success=true
    fi

    if [ "$success" = true ]; then
      break
    elif [ "$LOCAL_FAILURE" = true ] && [ "$attempt" -eq 1 ]; then
      local_flag=false
      attempt=$((attempt + 1))
      print_checker "$CROSS Web test failed due to Local tunnel error.\n🔁 Retrying web test without browserstackLocal..."
      cd "$BSS_SETUP_DIR"
    elif [ "$SETUP_FAILURE" = true ]; then
      print_checker "$CROSS Web test failed due to setup error. Check logs at:\n📄 $run_result_log_path"
      break
    else
      break
    fi
  done

  if [ "$success" = true ]; then
    BUILD_URL=$(grep -Eo "https://[a-zA-Z0-9./?=_-]*browserstack\.com[a-zA-Z0-9./?=_-]*" "$LOG_FILE" | tail -n 1)
    if [ -n "$BUILD_URL" ]; then
      print_checker "$TICK Web test run completed. View your tests here:\n👉 $BUILD_URL"
    else
      print_checker "$TICK Web test run completed. Visit your BrowserStack dashboard to view results."
    fi
  else
    print_checker "$CROSS Final Web setup failed.\nCheck logs at: $run_result_log_path\nIf the issue persists, retry or contact: support@browserstack.com"
  fi
}





#############################################
# Step 7: Setup Mobile with retry on Local true
#############################################

# Mobile Errors
MOBILE_SETUP_ERRORS=("")
MOBILE_LOCAL_ERRORS=("tunnel connection error")

setup_mobile_java() {
  local_flag=$1
  parallels=$2
  log_file=$3

  REPO="testng-appium-app-browserstack"
  [ ! -d "$REPO" ] && git clone -b master https://github.com/browserstack/$REPO
  cd "$REPO" || return

  validate_prereqs || return 1
  platform_yaml=$(generate_mobile_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE")

  cat > android/testng-examples/browserstack.yml <<EOF
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: testng
app: bs://sample.app
platforms:
$platform_yaml
browserstackLocal: $local_flag
buildName: browserstack-build-1
projectName: BrowserStack Sample
EOF

  cd android/testng-examples || return
  mvn test -P sample-test > "$log_file" 2>&1
  cat "$log_file" >> "$LOG_FILE"
}

setup_mobile_python() {
  local_flag=$1
  parallels=$2
  log_file=$3

  REPO="python-appium-app-browserstack"
  [ ! -d "$REPO" ] && git clone https://github.com/browserstack/$REPO
  cd "$REPO" || return

  validate_prereqs || return 1
  python3 -m venv env && source env/bin/activate
  pip3 install -r requirements.txt && cd android >> "$LOG_FILE" 2>&1
  platform_yaml=$(generate_mobile_platforms_yaml "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE")
  
  platform_yaml

  cat > browserstack.yml <<EOF
userName: $BS_USERNAME
accessKey: $BS_ACCESS_KEY
framework: python
app: bs://sample.app
platforms:
$platform_yaml
browserstackLocal: $local_flag
buildName: browserstack-build-1
projectName: BrowserStack Sample
EOF

  browserstack-sdk python browserstack_sample.py > "$log_file" 2>&1
  cat "$log_file" >> "$LOG_FILE"
}

# setup_mobile_js() {
#   local_flag=$1
#   parallels=$2
#   log_file=$3

#   REPO="webdriverio-appium-app-browserstack"
#   [ ! -d "$REPO" ] && git clone -b sdk https://github.com/browserstack/$REPO
#   cd "$REPO/android" || return

#   validate_prereqs || return 1
#   npm install >> "$LOG_FILE" 2>&1

#   export BROWSERSTACK_USERNAME="$BS_USERNAME"
#   export BROWSERSTACK_ACCESS_KEY="$BS_ACCESS_KEY"
#   export BROWSERSTACK_LOCAL=$local_flag

#   if [ "$local_flag" = true ]; then
#     npm run local > "$log_file" 2>&1
#   else
#     npm run test > "$log_file" 2>&1
#   fi

#   cat "$log_file" >> "$LOG_FILE"
# }

setup_mobile_js() {
  local_flag=$1
  parallels=$2
  log_file=$3

  REPO="webdriverio-appium-app-browserstack"
  [ ! -d "$REPO" ] && git clone -b sdk https://github.com/browserstack/$REPO
  cd "$REPO/android/examples/run-parallel-test" || return

  validate_prereqs || return 1
  npm install >> "$LOG_FILE" 2>&1

  local caps_json
  caps_json=$(generate_mobile_caps_json "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE")
  local conf_file="parallel.conf.js"

  jq ".maxInstances = $TEAM_PARALLELS_MAX_ALLOWED_MOBILE | .capabilities = [$caps_json]" "$conf_file" > tmp.json && mv tmp.json "$conf_file"

  export BROWSERSTACK_USERNAME="$BS_USERNAME"
  export BROWSERSTACK_ACCESS_KEY="$BS_ACCESS_KEY"
  export BROWSERSTACK_LOCAL=$local_flag

  cd "../../" || return
  ls

  if [ "$local_flag" = true ]; then
    npm run local > "$log_file" 2>&1
  else
    npm run parallel > "$log_file" 2>&1
  fi

  cat "$log_file" >> "$LOG_FILE"
}



setup_mobile() {
  log "\n${BOLD}${BLUE}[Starting Mobile Setup for $TECH_STACK]${NC}"
  local local_flag=true
  local attempt=1
  local success=false
  local run_result_log="$BSS_SETUP_DIR/mobile_run_result.log"
  mkdir -p "$(dirname "$run_result_log")"
  local run_result_log_path
  run_result_log_path="$(realpath "$run_result_log")"
  rm -f "$run_result_log"


  total_parallels=$(echo "$TEAM_PARALLELS_MAX_ALLOWED_MOBILE * $PARALLEL_PERCENTAGE" | bc | cut -d'.' -f1)
  parallels_per_platform=$(( (total_parallels + 2) / 3 ))

  while [ "$attempt" -le 2 ]; do
    if [ "$SHOW_LOGS" = false ]; then
      echo -e "\n${YELLOW}[⏳ Please hold on while we prepare the next step in the background...]${NC}"
    fi

    log "[Mobile Setup Attempt $attempt] browserstackLocal: $local_flag"

    case "$TECH_STACK" in
      Java)       setup_mobile_java "$local_flag" "$parallels_per_platform" "$run_result_log" ;;
      Python)     setup_mobile_python "$local_flag" "$parallels_per_platform" "$run_result_log" ;;
      JavaScript) setup_mobile_js "$local_flag" "$parallels_per_platform" "$run_result_log" ;;
    esac

    LOG_CONTENT=$(<"$run_result_log")
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
      break
    elif [ "$LOCAL_FAILURE" = true ] && [ "$attempt" -eq 1 ]; then
      local_flag=false
      attempt=$((attempt + 1))
      print_checker "$CROSS Mobile test failed due to Local tunnel error.\n🔁 Retrying mobile test without browserstackLocal..."
      cd "$BSS_SETUP_DIR"
    elif [ "$SETUP_FAILURE" = true ]; then
      print_checker "$CROSS Mobile test failed due to setup error. Check logs at:\n📄 $run_result_log_path"
      break
    else
      break
    fi
  done

  if [ "$success" = true ]; then
    BUILD_URL=$(grep -Eo "https://[a-zA-Z0-9./?=_-]*browserstack\.com[a-zA-Z0-9./?=_-]*" "$LOG_FILE" | tail -n 1)
    if [ -n "$BUILD_URL" ]; then
      print_checker "$TICK Mobile test run completed. View your tests here:\n👉 $BUILD_URL"
    else
      print_checker "$TICK Mobile test run completed. Visit your BrowserStack dashboard to view results."
    fi
  else
    print_checker "$CROSS Final Mobile setup failed.\nCheck logs at: $run_result_log_path\nIf the issue persists, retry or contact: support@browserstack.com"
  fi
}






#############################################
# Step 8: Execute
#############################################
run_setup() {
  if [ "$TEST_OPTION" == "Web Testing" ]; then
    setup_web

  elif [ "$TEST_OPTION" == "Mobile App Testing" ]; then
    setup_mobile

  elif [ "$TEST_OPTION" == "Both" ]; then
    local ran_any=false

    if [ "$WEB_PLAN_FETCHED" == true ]; then
      setup_web
      ran_any=true
    else
      print_checker "${YELLOW}⚠️ Skipping Web setup as Web Testing plan was not fetched.${NC}"
    fi

    if [ "$MOBILE_PLAN_FETCHED" == true ]; then
      setup_mobile
      ran_any=true
    else
      print_checker "${YELLOW}⚠️ Skipping Mobile setup as Mobile App Testing plan was not fetched.${NC}"
    fi

    if [ "$ran_any" == false ]; then
      print_checker "${RED}❌ Both Web and Mobile setup were skipped. Exiting.${NC}"
      exit 1
    fi
  fi
}


# Main Execution Flow

setup_workspace
prompt_credentials
prompt_test_options
validate_prereqs
fetch_plan_details
run_setup
