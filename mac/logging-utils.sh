#!/usr/bin/env bash
#set -e

# ==============================================
# 🎨 COLOR & STYLE DEFINITIONS
# ==============================================
BOLD="\033[1m"
RESET="\033[0m"
GREEN="\033[32m"
YELLOW="\033[33m"
CYAN="\033[36m"
RED="\033[31m"
LIGHT_GRAY='\033[0;37m'

# ==============================================
# 🪄 LOGGING HELPERS
# ==============================================
log_section() {
  echo ""
  echo -e "${BOLD}${CYAN}───────────────────────────────────────────────${RESET}"
  echo -e "${BOLD}$1${RESET}"
  echo -e "${BOLD}${CYAN}───────────────────────────────────────────────${RESET}"
}

log_info()    { echo -e "${LIGHT_GRAY}ℹ️  $1${RESET}"; }
log_success() { echo -e "${GREEN}✅  $1${RESET}"; }
log_warn()    { echo -e "${YELLOW}⚠️  $1${RESET}"; }
log_error()   { echo -e "${RED}❌  $1${RESET}"; }

