#!/bin/bash

set -e

echo "=============================================="
echo "       XFCE + XRDP RAILWAY SERVER"
echo "=============================================="

echo ""
echo "[1] Python:"
python --version
python3 --version
python -m pip --version

echo ""
echo "[2] Checking required programs..."

command -v xrdp
command -v xrdp-sesman
command -v startxfce4

echo ""
echo "[3] Preparing DBus..."

mkdir -p /run/dbus

dbus-uuidgen --ensure=/etc/machine-id

dbus-daemon --system --fork || true

echo ""
echo "[4] Preparing PulseAudio..."

mkdir -p /run/user/0
chmod 700 /run/user/0

export XDG_RUNTIME_DIR=/run/user/0

pulseaudio \
    --system \
    --disallow-exit \
    --disable-shm \
    --exit-idle-time=-1 \
    2>/dev/null || true

echo ""
echo "[5] Starting XRDP session manager..."

mkdir -p /run/xrdp
mkdir -p /var/log/xrdp

chown xrdp:xrdp /run/xrdp 2>/dev/null || true

/usr/sbin/xrdp-sesman &

sleep 2

echo ""
echo "[6] Starting XRDP on port 3389..."
echo ""

exec /usr/sbin/xrdp --nodaemon
