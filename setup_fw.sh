#!/bin/bash

INTERFACE="virbr1"
PORT="8082"

echo "Configuring firewall for QEMU/KVM guest access..."

HOST_IP=$(ip -4 -br addr show "$INTERFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)

if [ -z "$HOST_IP" ]; then
    echo "Error: Could not find an active IP for interface '$INTERFACE'."
    exit 1
fi

echo "Adding UFW rule to allow TCP traffic on $INTERFACE to port $PORT..."
sudo ufw allow in on "$INTERFACE" to any port "$PORT" proto tcp > /dev/null

echo "Firewall rule successfully applied!"