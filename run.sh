#!/bin/bash

INTERFACE="virbr1"
PORT="8082"

# 0. enforce arguments and show usage
if [ $# -eq 0 ]; then
    echo "Error: You must specify a startup mode."
    echo "Usage: ./run.sh [fw | fast]"
    echo "  fw   : Run firewall setup (requires sudo)"
    echo "  fast : Skip firewall setup for quick restarts (also accepts -f or --fast)"
    exit 1
fi

SKIP_FW=""

for arg in "$@"; do
    if [[ "$arg" == "fast" || "$arg" == "-f" || "$arg" == "--fast" || "$arg" == "--no-fw" ]]; then
        SKIP_FW=true
    elif [[ "$arg" == "fw" || "$arg" == "-w" || "$arg" == "--fw" ]]; then
        SKIP_FW=false
    else
        echo "Error: Unknown argument '$arg'."
        echo "Usage: ./run.sh [fw | fast]"
        exit 1
    fi
done

# 1. trigger the firewall setup based on user choice
if [ "$SKIP_FW" = false ]; then
    if [ -f "./setup_fw.sh" ]; then
        echo "Running firewall configuration..."
        ./setup_fw.sh
    else
        echo "Warning: setup_fw.sh not found. Skipping firewall configuration."
    fi
else
    echo "Fast mode enabled: Skipping firewall configuration."
fi

# 2. dynamically find the bridge IP and write it to the poc config file
HOST_IP=$(ip -4 -br addr show "$INTERFACE" 2>/dev/null | awk '{print $3}' | cut -d/ -f1)

if [ -z "$HOST_IP" ]; then
    echo "Error: Could not find IP for $INTERFACE. Falling back to 127.0.0.1"
    HOST_IP="127.0.0.1"
fi

POC_CONFIG_FILE="./poc/config.sh"
if [ -f "$POC_CONFIG_FILE" ]; then
    echo "Updating $POC_CONFIG_FILE with TARGET_IP http://$HOST_IP:$PORT"
    # use sed to replace the line starting with TARGET_IP=
    # we use | as delimiter to avoid issues with slashes in http://
    sed -i "s|^TARGET_IP=.*|TARGET_IP=\"http://$HOST_IP:$PORT\"|" "$POC_CONFIG_FILE"
else
    echo "$POC_CONFIG_FILE not found. Creating it."
    echo -e "#!/bin/bash\n\nTARGET_IP=\"http://$HOST_IP:$PORT\"" > "$POC_CONFIG_FILE"
fi

# 3. handle venv 
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment and installing dependencies..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
fi

# 4. connection summary
echo ""
echo "=================================================="
echo "APP IS READY"
echo "=================================================="
echo "Access your app from the Kali VM at:"
echo "http://$HOST_IP:$PORT"
echo ""
echo "Quick test command to run inside Kali:"
echo "curl http://$HOST_IP:$PORT"
echo "=================================================="
echo ""

# 5. run
.venv/bin/uvicorn app.main:app --reload --host "$HOST_IP" --port "$PORT"
