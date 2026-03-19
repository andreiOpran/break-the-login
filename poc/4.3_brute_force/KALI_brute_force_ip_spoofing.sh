#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

TARGET_EMAIL="4.3@example.com"


# spoof "X-Forwarded-For" header to make the server think each request came from different IP
# i also made the slowapi to look for the "X-Forwarded-For" first and then look for the actual
# Kali VM IP, so this can actually work with localhost server and Kali VM

for i in {1..12}
do
  FAKE_IP="$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256)).$((RANDOM % 256))"
  
  echo "[Attempt $i] Sending attack from spoofed IP: $FAKE_IP"
  
  RESPONSE=$(curl -s -X POST "$TARGET_IP/auth/login" \
    -H "Content-Type: application/json" \
    -H "X-Forwarded-For: $FAKE_IP" \
    -d "{\"email\": \"$TARGET_EMAIL\", \"password\": \"ThisIsNotThePassword_$i\"}")
  
  echo "$RESPONSE" | jq .
  if echo "$RESPONSE" | grep -iq "Rate limit exceeded\|Account temporarily locked"; then
    echo "[FIXED] Blocked despite IP rotation"
    exit 0
  fi
done

echo "[VULNERABLE] Bypassed rate limiting via IP spoofing"
exit 1
