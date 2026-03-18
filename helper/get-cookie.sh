#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
# YELLOW='\033[1;33m'
# BLUE='\033[0;34m'
NC='\033[0m' # No Color
COOKIE_FILE="cookie.txt"

echo "Check README for cookie instructions."
read -rp "Please paste your full GitHub 'Cookie' header string here: " cookie

if [[ -z "$cookie" ]]; then
    echo -e "${RED}Error: No cookie string entered. Exiting.${NC}"
    exit 1
fi

echo "Cookie: $cookie" > "$COOKIE_FILE"
chmod 600 "$COOKIE_FILE" # Set secure permissions (only owner can read/write)
echo "${GREEN}Cookie string saved securely to '$COOKIE_FILE'.${NC}"

