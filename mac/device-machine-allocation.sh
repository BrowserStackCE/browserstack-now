#!/bin/bash

# ---------------------------
# Usage: ./pick_devices.sh <platformName> <count>
# Example: ./pick_devices.sh android 3
# ---------------------------


# Define array of devices
MOBILE_ALL=(
  # Tier 1
  "ios|iPhone 1[234567]*"
  "android|Samsung Galaxy S*"

  # Tier 2
  "ios|iPad Air*"
  "android|Samsung Galaxy Tab*"
  "android|Samsung Galaxy M*"
  "android|Google Pixel [56789]*"
  "android|Vivo Y*"
  "android|Oppo*"

  # Tier 4
  "ios|iPad Pro*"
  "android|Samsung Galaxy A*"
  "android|Google Pixel 10*"
  "android|OnePlus *"
  "android|Vivo V*"
  "android|Xiaomi *"
  "android|Huawei *"
)

WEB_ALL=(
  "Windows|Chrome"
  "Windows|Firefox"
  "Windows|Edge"
  "Windows|Chrome"
  "Windows|Chrome"
  "OS X|Chrome"
  "OS X|Safari"
  "OS X|Chrome"
  "OS X|Safari"
  "OS X|Firefox"
  "OS X|Safari"
    # Tier 1
  "ios|iPhone 1[234567]*"
  "android|Samsung Galaxy S*"

  # Tier 2
  "ios|iPad Air*"
  "android|Samsung Galaxy Tab*"
  "android|Samsung Galaxy M*"
  "android|Google Pixel [56789]*"
  "android|Vivo Y*"
  "android|Oppo*"

  # Tier 4
  "ios|iPhone SE*"
  "ios|iPad Pro*"
  "android|Samsung Galaxy A*"
  "android|Google Pixel 10*"
  "android|OnePlus *"
  "android|Vivo V*"
  "android|Xiaomi *"
  "android|Huawei *"
)



pick_terminal_devices() {
  local platformName="$1"
  local count=$2
  count="${count%,}"   # remove trailing comma if present
  local platformsListContentFormat="$3"

  # ---------------------------
  # Check for valid input
  # ---------------------------
  if [[ -z "$platformName" || -z "$count" ]]; then
    log_msg_to "Platform name for parallel count is invalid: $platformName $count"
    return 1
  fi

  # Validate count is a number
  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    log_msg_to "Error: count must be a number."
    return 1
  fi

  # ---------------------------
  # Filter and store matching entries
  # ---------------------------
  matching_devices=()

  if [[ "$platformName" == "android" || "$platformName" == "ios" ]]; then
    for entry in "${MOBILE_ALL[@]}"; do
      prefix="${entry%%|*}"  # text before '|'
      if [[ "$prefix" == "$platformName" ]]; then
        matching_devices+=("$entry")
      fi
    done
  else
    for entry in "${WEB_ALL[@]}"; do
      matching_devices+=("$entry")
    done
  fi

  # ---------------------------
  # Loop as many times as 'count'
  # ---------------------------
  local yaml=""
  local json="["

  for ((i = 1; i <= count; i++)); do
    index=$(( (i - 1) % ${#matching_devices[@]} ))
    entry="${matching_devices[$index]}"
    suffixEntry="${entry#*|}"
    prefixEntry="${entry%%|*}"
    bVersionLiteral=""
    mod=$(( i % 4 ))

    if [ $((i % 4)) -ne 0 ]; then
      bVersionLiteral="-$mod"
    else
      bVersionLiteral=""
    fi
    bVersion="latest$bVersionLiteral"
    if [[ "$platformsListContentFormat" == "yaml" ]]; then
      if [[ "$prefixEntry" == "android" || "$prefixEntry" == "ios" ]]; then  
        yaml+="  - platformName: $prefixEntry
    deviceName: $suffixEntry
"
      else
        yaml+="  - osVersion: $prefixEntry
    browserName: $suffixEntry
    browserVersion: $bVersion
"
      fi

      # Add comma-like separator logic here only if needed
      if [[ $i -lt $count ]]; then
        yaml+=$'\n'
      fi

    elif [[ "$platformsListContentFormat" == "json" ]]; then
      # JSON mode
      if [[ "$prefixEntry" == "android" || "$prefixEntry" == "ios" ]]; then
        json+=$'{"platformName": "'"$prefixEntry"'","bstack:options":{"deviceName": "'"$suffixEntry"'"}},'
      else
        json+=$'{"bstack:options":{ "os": "'"$prefixEntry"'"},"browserName": "'"$suffixEntry"'","browserVersion": "'"$bVersion"'"},'
      fi

      # Stop if max reached
      if [[ -n "$max_total" && $i -ge $max_total ]]; then
        break
      fi
    fi
  done
  
  # Close JSON array
  json="${json%,}]"

  # Output based on requested format
  if [[ "$platformsListContentFormat" == "yaml" ]]; then
    echo "$yaml"
  else
    echo "$json"
  fi
}