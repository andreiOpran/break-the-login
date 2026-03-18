#!/bin/bash

# source config from parent directory
source $(dirname "$0")/../config.sh

echo "TESTING USER ENUMERATION (messages and timing):"

# test email, record response time, and parse return message
# return via stdout separated by "|"
test_email() {
    local email=$1
    local label=$2
    local verbose=${3:-true}
    
    # run curl and get results
    local result=$(curl -s -w "\n%{time_total}" -X POST "$TARGET_IP/auth/login" \
        -H "Content-Type: application/json" \
        -d "{\"email\": \"$email\", \"password\": \"ThisIsNotThePassword\"}")
    
    local time_total=$(echo "$result" | tail -n1)
    local msg=$(echo "$result" | sed '$d' | jq -r .detail 2>/dev/null)
    
    if [ "$verbose" = true ]; then
        echo "[$label] $email: Received \"$msg\" in $time_total seconds" >&2
    fi
    
    # return via stdout
    echo "$time_total|$msg"
}

# warming up via test_email() to init hashing context
test_email "warmup@example.com" "WARMUP" false > /dev/null
test_email "warmup@example.com" "WARMUP" false > /dev/null

# run tests and capture output
RES1=$(test_email "4.4@example.com" "EXISTING" true)
TIME1=$(echo "$RES1" | cut -d'|' -f1)
MSG1=$(echo "$RES1" | cut -d'|' -f2)

RES2=$(test_email "fake4.4@example.com" "NON-EXIST" true)
TIME2=$(echo "$RES2" | cut -d'|' -f1)
MSG2=$(echo "$RES2" | cut -d'|' -f2)

TIME_DIFF=$(awk -v t1=$TIME1 -v t2=$TIME2 'BEGIN { d = t1 - t2; if (d < 0) d = -d; print d }')


echo -e "\nRESULTS OF ABOVE USER ENUMERATION:"

# check if messages are the same
if [ "$MSG1" != "$MSG2" ]; then
    echo "[VULNERABLE - MESSAGE] Error messages leak existence ('$MSG1' vs '$MSG2')"
else
    echo "[FIXED - MESSAGE] Error messages are IDENTICAL ('$MSG1' vs '$MSG2')"
fi

# check if there is a distinguishable time difference between the 2 requests
# we set the difference threshold to 50ms, although the passlib.dummy_verify() gets it under 5ms
IS_VULNERABLE=$(awk -v d=$TIME_DIFF 'BEGIN { if (d > 0.05) print "1"; else print "0" }')

if [ "$IS_VULNERABLE" -eq "1" ]; then
    echo "[WARNING - TIMING] Response times are distinguishable (>50ms). Timing attacks are a possible way of user enumerating."
else
    echo "[FIXED - TIMING] Response times are indistinguishable. Timing attacks are not possible."
fi
echo "Time difference between \"Existing\" and \"Non-existing\" user check: $TIME_DIFF seconds"

# cleanup
rm /tmp/*_msg.txt /tmp/*_time.txt 2>/dev/null
