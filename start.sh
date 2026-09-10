#!/bin/bash

set -e

echo "========================================"
echo " RS ANIME XRDP SERVER"
echo "========================================"

echo ""
echo "[1/6] Python version:"
python --version
python3 --version
pip --version

echo ""
echo "[2/6] Starting DBus..."

mkdir -p /run/dbus

if [ ! -f /etc/machine-id ]; then
    dbus-uuidgen --ensure=/etc/machine-id
fi

dbus-daemon --system --fork || true

echo ""
echo "[3/6] Preparing PulseAudio..."

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
echo "[4/6] Starting XRDP..."

mkdir -p /var/run/xrdp
mkdir -p /var/log/xrdp

chown xrdp:xrdp /var/run/xrdp 2>/dev/null || true

/usr/sbin/xrdp-sesman &
sleep 2

/usr/sbin/xrdp --nodaemon
