#!/bin/bash

HASH=f25a2fc72690b780b2a14e140ef6a9e0

# get hash type
hashid $HASH

echo $HASH > hash.txt
john --format=raw-md5 --wordlist=/usr/share/wordlists/rockyou.txt hash.txt
john --show --format=raw-md5 hash.txt
