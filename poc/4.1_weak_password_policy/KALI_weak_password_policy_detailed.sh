#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

echo -e "\n1. Failing Length (< 8 characters)"
TARGET_EMAIL="4.1_len_$RANDOM@example.com"
curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"short\"}" | jq .

echo -e "\n2. Failing Uppercase Check (has length, no uppercase)"
TARGET_EMAIL="4.1_up_$RANDOM@example.com"
curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"longpassword\"}" | jq .

echo -e "\n3. Failing Lowercase Check (has length and uppercase, no lowercase)"
TARGET_EMAIL="4.1_low_$RANDOM@example.com"
curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"LONGPASSWORD\"}" | jq .

echo -e "\n4. Failing Digit Check (has length, upper, lower, no number)"
TARGET_EMAIL="4.1_num_$RANDOM@example.com"
curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"LongPassword\"}" | jq .

echo -e "\n5. Failing Special Char Check (has length, upper, lower, and number)"
TARGET_EMAIL="4.1_spec_$RANDOM@example.com"
curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"LongPassword123\"}" | jq .

echo -e "\n6. SUCCESS (meets all criteria)"
TARGET_EMAIL="4.1_success_$RANDOM@example.com"
FINAL_RES=$(curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"LongPassword123!\"}")
echo "$FINAL_RES" | jq .

if echo "$FINAL_RES" | grep -q 'message'; then
  exit 0
else
  exit 1
fi
