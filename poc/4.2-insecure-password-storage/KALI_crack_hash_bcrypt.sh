#!/bin/bash

HASH='$2b$12$FTtZcYo6A9UM/nUImf7nqeAIF3zW6/ghRlm7nd8CvP3/ooP2aq3mO'

# get hash type
hashid "$HASH"

echo "$HASH" > hash_bcrypt.txt

# '--pot=bcrypt_temp.pot' to ignore cached crack
echo -e "\n[!] Starting timed crack with bcrypt format..."
time john --format=bcrypt --wordlist=/usr/share/wordlists/rockyou.txt --pot=bcrypt_temp.pot hash_bcrypt.txt

echo -e "\n[!] Viewing cracked result:"
john --show --format=bcrypt --pot=bcrypt_temp.pot hash_bcrypt.txt
rm bcrypt_temp.pot