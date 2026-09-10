#!/bin/bash

set -e

echo "=========================================="
echo "       RS ANIME XRDP SERVER"
echo "=========================================="

echo "[1/6] Preparing DBus..."

mkdir -p /var/run/dbus
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

dbus-uuidgen --ensure=/etc/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

service dbus start 2>/dev/null || true

echo "✓ DBus ready"

echo "[2/6] Checking XRDP TLS..."

test -s /etc/xrdp/cert.pem
test -s /etc/xrdp/key.pem

echo "✓ TLS certificate found"
echo "✓ TLS private key found"

echo "[3/6] Checking XRDP configuration..."

echo "Port:"
grep -E '^port=' /etc/xrdp/xrdp.ini

echo "Security:"
grep -E '^security_layer=' /etc/xrdp/xrdp.ini

echo "[4/6] Preparing PulseAudio..."

pulseaudio \
    --system \
    --disallow-exit \
    --disable-shm \
    --daemonize=yes \
    2>/dev/null || true

echo "✓ PulseAudio ready"

echo "[5/6] Starting XRDP..."

# Kill old processes if any
pkill -x xrdp 2>/dev/null || true
pkill -x xrdp-sesman 2>/dev/null || true

sleep 1

# Start XRDP session manager directly.
# Do NOT use: service xrdp-sesman
/usr/sbin/xrdp-sesman &

sleep 2

# Start XRDP directly.
/usr/sbin/xrdp --nodaemon &
XRDP_PID=$!

sleep 3

echo "[6/6] Checking XRDP..."

if kill -0 "$XRDP_PID" 2>/dev/null; then
    echo "✓ xrdp is running"
else
    echo "ERROR: xrdp failed to start"
    echo "========== XRDP LOG =========="
    cat /var/log/xrdp.log 2>/dev/null || true
    echo "======= XRDP SESMAN LOG ======="
    cat /var/log/xrdp-sesman.log 2>/dev/null || true
    exit 1
fi

if pgrep -x xrdp-sesman >/dev/null; then
    echo "✓ xrdp-sesman is running"
else
    echo "ERROR: xrdp-sesman failed to start"
    cat /var/log/xrdp-sesman.log 2>/dev/null || true
    exit 1
fi

if ss -lntp 2>/dev/null | grep -q ':3389'; then
    echo "✓ Port 3389 is listening"
else
    echo "ERROR: Port 3389 is NOT listening"
    cat /var/log/xrdp.log 2>/dev/null || true
    exit 1
fi

echo ""
echo "=========================================="
echo "       XRDP SERVER READY"
echo "=========================================="
echo "RDP Port : 3389"
echo "Username : root"
echo "Password : root"
echo "Security : TLS"
echo "Python   : $(python --version)"
echo "Listen   : 0.0.0.0:3389"
echo "=========================================="
echo "Waiting for RDP connections..."
echo "=========================================="

# Keep container alive and show logs
tail -F /var/log/xrdp.log /var/log/xrdp-sesman.log &
TAIL_PID=$!

wait "$XRDP_PID"
