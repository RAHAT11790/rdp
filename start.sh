#!/bin/bash

set -u

echo "=============================================="
echo "        RS ANIME XRDP CONTAINER"
echo "=============================================="
echo ""

# --------------------------------------------------
# Basic directories
# --------------------------------------------------
mkdir -p /run/dbus
mkdir -p /var/run/dbus
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

# --------------------------------------------------
# Machine ID
# --------------------------------------------------
dbus-uuidgen --ensure=/etc/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# --------------------------------------------------
# Clean old XRDP processes
# --------------------------------------------------
pkill -x xrdp 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true

sleep 1

# --------------------------------------------------
# Check certificate
# --------------------------------------------------
echo "[1/7] Checking TLS certificate..."

if [ ! -s /etc/xrdp/cert.pem ]; then
    echo "ERROR: XRDP certificate missing"
    exit 1
fi

if [ ! -s /etc/xrdp/key.pem ]; then
    echo "ERROR: XRDP private key missing"
    exit 1
fi

echo "      TLS certificate: OK"
echo "      TLS private key: OK"

# --------------------------------------------------
# Check configuration
# --------------------------------------------------
echo ""
echo "[2/7] Checking XRDP configuration..."

echo "      Port:"
grep -E '^[[:space:]]*port=' /etc/xrdp/xrdp.ini || true

echo "      Security:"
grep -E '^[[:space:]]*security_layer=' /etc/xrdp/xrdp.ini || true

echo "      Root login:"
grep -E '^[[:space:]]*AllowRootLogin=' /etc/xrdp/sesman.ini || true

# --------------------------------------------------
# Start DBus
# --------------------------------------------------
echo ""
echo "[3/7] Starting DBus..."

if command -v dbus-daemon >/dev/null 2>&1; then
    dbus-daemon --system --fork 2>/dev/null || true
fi

echo "      DBus: ready"

# --------------------------------------------------
# PulseAudio
# --------------------------------------------------
echo ""
echo "[4/7] Preparing audio..."

pulseaudio \
    --system \
    --disallow-exit \
    --disable-shm \
    --daemonize=yes \
    >/tmp/pulseaudio.log 2>&1 || true

echo "      PulseAudio: ready"

# --------------------------------------------------
# Start XRDP session manager
# IMPORTANT:
# Do NOT use "service xrdp-sesman".
# Docker does not run systemd.
# --------------------------------------------------
echo ""
echo "[5/7] Starting XRDP session manager..."

/usr/sbin/xrdp-sesman \
    >/var/log/xrdp-sesman-console.log 2>&1 &

SESMAN_PID=$!

sleep 2

if kill -0 "$SESMAN_PID" 2>/dev/null; then
    echo "      xrdp-sesman: running"
else
    echo "ERROR: xrdp-sesman failed"
    cat /var/log/xrdp-sesman-console.log 2>/dev/null || true
    cat /var/log/xrdp-sesman.log 2>/dev/null || true
    exit 1
fi

# --------------------------------------------------
# Start XRDP
# --------------------------------------------------
echo ""
echo "[6/7] Starting XRDP..."

/usr/sbin/xrdp \
    --nodaemon \
    >/var/log/xrdp-console.log 2>&1 &

XRDP_PID=$!

sleep 3

if ! kill -0 "$XRDP_PID" 2>/dev/null; then

    echo "ERROR: XRDP failed to start"

    echo ""
    echo "========== XRDP CONSOLE =========="
    cat /var/log/xrdp-console.log 2>/dev/null || true

    echo ""
    echo "========== XRDP LOG =========="
    cat /var/log/xrdp.log 2>/dev/null || true

    echo ""
    echo "========== SESMAN LOG =========="
    cat /var/log/xrdp-sesman.log 2>/dev/null || true

    exit 1
fi

# --------------------------------------------------
# Verify listening port
# --------------------------------------------------
echo ""
echo "[7/7] Verifying port 3389..."

LISTEN_OK=0

for i in {1..10}; do

    if ss -lnt 2>/dev/null | grep -q ':3389 '; then
        LISTEN_OK=1
        break
    fi

    sleep 1

done

if [ "$LISTEN_OK" -ne 1 ]; then

    echo "ERROR: Port 3389 is not listening"

    echo ""
    echo "========== XRDP LOG =========="
    cat /var/log/xrdp.log 2>/dev/null || true

    echo ""
    echo "========== SESMAN LOG =========="
    cat /var/log/xrdp-sesman.log 2>/dev/null || true

    exit 1
fi

echo "      Port 3389: LISTENING"

echo ""
echo "=============================================="
echo "          XRDP SERVER IS READY"
echo "=============================================="
echo ""
echo " Desktop  : XFCE"
echo " Protocol : RDP"
echo " Security : TLS"
echo " Port     : 3389"
echo " User     : root"
echo " Password : root"
echo " Python   : $(python --version 2>&1)"
echo "=============================================="
echo ""
echo "Waiting for RDP connections..."
echo ""

# --------------------------------------------------
# Keep container alive.
# XRDP stays in background.
# If either critical process dies, container exits
# so Railway can restart it.
# --------------------------------------------------
while true; do

    if ! kill -0 "$XRDP_PID" 2>/dev/null; then
        echo "ERROR: xrdp process stopped"
        cat /var/log/xrdp.log 2>/dev/null || true
        exit 1
    fi

    if ! kill -0 "$SESMAN_PID" 2>/dev/null; then
        echo "ERROR: xrdp-sesman process stopped"
        cat /var/log/xrdp-sesman.log 2>/dev/null || true
        exit 1
    fi

    sleep 10

done
