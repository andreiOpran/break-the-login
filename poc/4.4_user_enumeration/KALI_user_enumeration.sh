#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

echo "EXISTING USER"
RES1=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "4.2@example.com", "password": "ThisIsNotThePassword"}')
echo "$RES1" | jq .

echo "NON-EXISTING USER"
RES2=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email": "fake@email.com", "password": "ThisIsNotThePassword"}')
echo "$RES2" | jq .

MSG1=$(echo "$RES1" | jq -r .detail)
MSG2=$(echo "$RES2" | jq -r .detail)

if [ "$MSG1" != "$MSG2" ]; then
    echo -e "\n[VULNERABLE] Error messages are DIFFERENT ('$MSG1' vs '$MSG2')"
else
    echo -e "\n[FIXED] Error messages are IDENTICAL"
fi
