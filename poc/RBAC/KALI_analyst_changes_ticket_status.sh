#!/bin/bash

# Source config from parent directory
source $(dirname "$0")/../config.sh

# TARGET_IP loaded from config.sh
SUFFIX=$RANDOM
ANALYST_EMAIL="RBAC_analyst_${SUFFIX}@example.com"
PASSWORD="password123"

echo -e "Registering analyst user"
REGISTER_RESP=$(curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$ANALYST_EMAIL\", \"password\": \"$PASSWORD\"}")
echo -e "$REGISTER_RESP" | jq .

echo -e "\nLogging in as analyst"
LOGIN_RESP=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$ANALYST_EMAIL\", \"password\": \"$PASSWORD\"}")
echo -e "$LOGIN_RESP" | jq .
ANALYST_TOKEN=$(echo -e "$LOGIN_RESP" | jq -r .access_token)

if [ -z "$ANALYST_TOKEN" ] || [ "$ANALYST_TOKEN" == "null" ]; then
    echo -e "Failed to get analyst token. Exiting."
    exit 1
fi

echo -e "\nAnalyst creates a ticket"
CREATE_RESP=$(curl -s -X POST "$TARGET_IP/tickets/" \
  -H "Authorization: Bearer $ANALYST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
  "title": "Analyst Ticket",
  "description": "Should not be able to resolve this as analyst.",
  "severity": "LOW"
}')
echo -e "$CREATE_RESP" | jq .
TICKET_ID=$(echo -e "$CREATE_RESP" | jq -r .id)

if [ -z "$TICKET_ID" ] || [ "$TICKET_ID" == "null" ]; then
    echo -e "Failed to create ticket. Exiting."
    exit 1
fi

echo -e "\nAnalyst attempts to change status to RESOLVED (should be forbidden)"
PATCH_RESP=$(curl -s -X PATCH "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ANALYST_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "RESOLVED"}')
echo -e "$PATCH_RESP" | jq .
