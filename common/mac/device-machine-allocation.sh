#!/bin/bash

CONFIG_FILE="$(dirname "$0")/../config/devices.txt"

get_devices() {
    local type=$1
    local devices=()
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        
        if [[ "$type" == "MOBILE" ]]; then
            if [[ "$line" == MOBILE* ]]; then
                devices+=("${line#MOBILE|}")
            fi
        else
            if [[ "$line" == WEB* ]]; then
                devices+=("${line#WEB|}")
            elif [[ "$line" == MOBILE* ]]; then
                # Web also includes mobile devices in the original script logic
                devices+=("${line#MOBILE|}")
            fi
        fi
    done < "$CONFIG_FILE"
    echo "${devices[@]}"
}

pick_terminal_devices() {
  local platformName="$1"
  local count=$2
  count="${count%,}"
  local platformsListContentFormat="$3"

  if [[ -z "$platformName" || -z "$count" ]]; then
    return 1
  fi

  # Read devices into array
  local matching_devices=()
  local raw_devices
  
  if [[ "$platformName" == "android" || "$platformName" == "ios" ]]; then
     # Filter specifically for the requested platform from the MOBILE list
     while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        if [[ "$line" == MOBILE* ]]; then
            entry="${line#MOBILE|}"
            prefix="${entry%%|*}"
            if [[ "$prefix" == "$platformName" ]]; then
                matching_devices+=("$entry")
            fi
        fi
     done < "$CONFIG_FILE"
  else
     # For Web, use everything (WEB + MOBILE) as per original logic
     while IFS= read -r line; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "$line" ]] && continue
        if [[ "$line" == WEB* ]]; then
            matching_devices+=("${line#WEB|}")
        elif [[ "$line" == MOBILE* ]]; then
            matching_devices+=("${line#MOBILE|}")
        fi
     done < "$CONFIG_FILE"
  fi

  if [ ${#matching_devices[@]} -eq 0 ]; then
      return 0
  fi

  local yaml=""
  local json="["

  for ((i = 1; i <= count; i++)); do
    index=$(( (i - 1) % ${#matching_devices[@]} ))
    entry="${matching_devices[$index]}"
    suffixEntry="${entry#*|}"
    prefixEntry="${entry%%|*}"
    
    mod=$(( i % 4 ))
    local hardcodedBVersion=140
    local bVersionLiteral=""
    
    if [ $((i % 4)) -ne 0 ]; then
      bVersionLiteral="-$mod"
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
    browserVersion: $(( hardcodedBVersion-i ))
"
      fi
      if [[ $i -lt $count ]]; then
        yaml+=$'\n'
      fi

    elif [[ "$platformsListContentFormat" == "json" ]]; then
      if [[ "$prefixEntry" == "android" || "$prefixEntry" == "ios" ]]; then
        json+=$'{"platformName": "'"$prefixEntry"'","bstack:options":{"deviceName": "'"$suffixEntry"'"}},'
      else
        json+=$'{"bstack:options":{ "os": "'"$prefixEntry"'"},"browserName": "'"$suffixEntry"'","browserVersion": "'"$bVersion"'"},'
      fi
    fi
  done
  
  json="${json%,}]"

  if [[ "$platformsListContentFormat" == "yaml" ]]; then
    echo "$yaml"
  else
    echo "$json"
  fi
}
