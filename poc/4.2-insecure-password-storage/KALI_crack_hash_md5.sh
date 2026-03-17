#!/bin/bash

HASH=f25a2fc72690b780b2a14e140ef6a9e0

# get hash type
hashid "$HASH"

echo "$HASH" > hash_md5.txt

# '--pot=mdt_temp.pot' to ignore cached crack
echo -e "\n[!] Starting timed crack with MD5 format..."
time john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou.txt --pot=md5_temp.pot hash_md5.txt

echo -e "\n[!] Viewing cracked result:"
john --show --format=raw-md5 --pot=md5_temp.pot hash_md5.txt
rm md5_temp.pot
