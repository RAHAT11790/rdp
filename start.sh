#!/bin/bash

set -e

echo "=========================================="
echo "       RS ANIME XRDP SERVER"
echo "=========================================="

echo "[1/6] Preparing DBus..."

mkdir -p /var/run/dbus
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

if [ ! -f /etc/machine-id ]; then
    dbus-uuidgen --ensure=/etc/machine-id
fi

ln -sf /etc/machine-id /var/lib/dbus/machine-id

service dbus start || true

echo "✓ DBus ready"

echo "[2/6] Checking XRDP TLS certificate..."

if [ ! -s /etc/xrdp/cert.pem ]; then
    echo "ERROR: XRDP certificate missing"
    exit 1
fi

if [ ! -s /etc/xrdp/key.pem ]; then
    echo "ERROR: XRDP private key missing"
    exit 1
fi

echo "✓ TLS certificate found"
echo "✓ TLS private key found"

echo "[3/6] Checking XRDP configuration..."

grep -E '^(port|security_layer)=' /etc/xrdp/xrdp.ini || true

echo "[4/6] Preparing PulseAudio..."

pulseaudio --system \
    --disallow-exit \
    --disable-shm \
    --daemonize=yes \
    2>/dev/null || true

echo "✓ PulseAudio ready"

echo "[5/6] Starting XRDP..."

service xrdp stop 2>/dev/null || true
service xrdp-sesman stop 2>/dev/null || true

service xrdp-sesman start
service xrdp start

sleep 2

echo "[6/6] XRDP status..."

if pgrep -x xrdp >/dev/null; then
    echo "✓ xrdp is running"
else
    echo "ERROR: xrdp failed to start"
    cat /var/log/xrdp.log 2>/dev/null || true
    exit 1
fi

if pgrep -x xrdp-sesman >/dev/null; then
    echo "✓ xrdp-sesman is running"
else
    echo "ERROR: xrdp-sesman failed to start"
    cat /var/log/xrdp-sesman.log 2>/dev/null || true
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
echo "=========================================="
echo "Waiting for RDP connections..."
echo "=========================================="

tail -F /var/log/xrdp.log /var/log/xrdp-sesman.log
