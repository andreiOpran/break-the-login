#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

TARGET_EMAIL="4.3@example.com"

echo "TRIPLE SHIELD VULNERABILITY TEST, targeting: $TARGET_EMAIL"

# SHIELD #1: Account Shield (IP + Email Limit)
# trigggered by multiple attempts for SAME email from SAME IP
echo -e "\n[TESTING SHIELD #1: IP + Email Rate Limit]"
# limit is 5/1 minute, attempt 6 will trigger the rate limit,
# total successes reaching DB logic: 5
for i in {1..7}
do
  echo -n "Attempt $i (Real IP) -> $TARGET_EMAIL: "
  curl -s -X POST "$TARGET_IP/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"ThisIsNotThePassword_$i\"}" | jq -c .
done

# SHIELD #2: Global IP Shield (Any Email Limit)
# triggered by attacker rotating victim emails but staying on one IP
echo -e "\n[TESTING SHIELD #2: Global IP Rate Limit (No Spare Emails)]"
# limit is 20/1 minute, we already did 7 requests in Shield #1,
# so we do 15 more to hit the global limit of 20 total for this IP
for i in {1..15} 
do
  FAKE_EMAIL="user_$i@attacker.com"
  echo -n "Attempt $i (Real IP) -> $FAKE_EMAIL: "
  curl -s -X POST "$TARGET_IP/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\": \"$FAKE_EMAIL\", \"password\": \"ThisIsNotThePassword_\"}" | jq -c .
done

# SHIELD #3: Inner Shield (DB Lockout)
# triggered by attacker rotating IPs but targeting the SAME email
echo -e "\n[TESTING SHIELD #3: DB Account Lockout (IP Spoofing)]"
echo "Spoofing X-Forwarded-For to bypass the SlowAPI IP limits..."
# DB_ACCOUNT_LOCKOUT_LIMIT is 7, Shield #1 successfully reached the DB 5 times (attempts 1-5),
# so we need 2 more failures to hit the 7 limit, then 1 more to see the locking
for i in {1..5}
do
  FAKE_IP="$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))"
  echo -n "Attempt $i (Spoofed IP: $FAKE_IP) -> $TARGET_EMAIL: "
    RES=$(curl -s -X POST "$TARGET_IP/auth/login" \
      -H "Content-Type: application/json" \
      -H "X-Forwarded-For: $FAKE_IP" \
      -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"ThisIsNotThePassword_shield_$i\"}")
    echo "$RES" | jq -c .
    
    if echo "$RES" | grep -iq "Account temporarily locked"; then
      echo "[FIXED] Rate Limits & DB Lockout verified"
      exit 0
    fi
  done
  
  echo "[VULNERABLE] Failed to trigger final DB Lockout"
  exit 1
