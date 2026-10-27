#!/bin/bash
set -e

# Screen resolution configuration (can be overridden via environment variables)
export SCREEN_WIDTH=${SCREEN_WIDTH:-1280}
export SCREEN_HEIGHT=${SCREEN_HEIGHT:-800}
export SCREEN_DEPTH=24
export DISPLAY=:99
export WEB_PORT=${PORT:-7860}

echo "=========================================================="
echo " Starting AURA Cloud Virtual Desktop"
echo " Display: $DISPLAY (${SCREEN_WIDTH}x${SCREEN_HEIGHT})"
echo " Web Port: $WEB_PORT"
echo "=========================================================="

# 1. Start Xvfb virtual framebuffer
echo "[1/5] Initializing Xvfb virtual display on $DISPLAY..."
Xvfb :99 -screen 0 ${SCREEN_WIDTH}x${SCREEN_HEIGHT}x${SCREEN_DEPTH} &
XVFB_PID=$!
sleep 1

# 2. Start lightweight Openbox window manager
echo "[2/5] Starting Openbox window manager..."
openbox &
OPENBOX_PID=$!
sleep 1

# 3. Start x11vnc server
echo "[3/5] Starting x11vnc server on port 5900..."
x11vnc -display :99 -forever -nopw -shared -rfbport 5900 -bg -quiet

# 4. Configure noVNC automatic redirect and launch websockify on port 7860
echo "[4/5] Setting up noVNC web streaming bridge on port $WEB_PORT..."
NOVNC_DIR="/usr/share/novnc"
if [ -d "$NOVNC_DIR" ]; then
    # Create auto-connecting index.html
    cat << 'EOF' > "$NOVNC_DIR/index.html"
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>AURA Neural Command Center</title>
    <meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=remote&reconnect=true">
    <style>
        body { background: #04060a; color: #00f0ff; font-family: sans-serif; display: flex; justify-content: center; align-items: center; height: 100vh; margin: 0; }
    </style>
</head>
<body>
    <h2>Initializing AURA Neural Interface...</h2>
</body>
</html>
EOF
fi

websockify --web="$NOVNC_DIR" "$WEB_PORT" localhost:5900 &
WEBSOCKIFY_PID=$!
sleep 1

# 5. Launch AURA Assistant
echo "[5/5] Launching AURA Python AI Assistant..."
python3 main.py

# Cleanup on exit
kill $WEBSOCKIFY_PID $OPENBOX_PID $XVFB_PID 2>/dev/null || true
