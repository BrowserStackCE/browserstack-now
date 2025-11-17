#!/bin/bash

detect_os() {
    local unameOut=""
    unameOut="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
    local response=""
    case "$unameOut" in
        linux*)
            # Detect WSL vs normal Linux
            if grep -qi "microsoft" /proc/version 2>/dev/null; then
                response="wsl"
            else
                response="linux"
            fi
            ;;
        darwin*)
            response="macos"
            ;;
        msys*|mingw*|cygwin*)
            response="windows"
            ;;
        *)
            response="unknown"
            ;;
    esac
    echo "OS is: $response"
    export NOW_OS=$response
}

detect_os

