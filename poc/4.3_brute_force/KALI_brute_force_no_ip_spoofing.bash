#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

TARGET_EMAIL="4.3@example.com"

for i in {1..7}
do
  echo "[Attempt $i] Sending attack from real IP..."
  
  RESPONSE=$(curl -s -X POST "$TARGET_IP/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"ThisIsNotThePassword_$i\"}")
  
  echo "$RESPONSE" | jq .
done
