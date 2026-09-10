#!/bin/bash

set -e

echo "=========================================="
echo "        Railway Debian XRDP Server"
echo "=========================================="

echo ""
echo "Python:"
python --version
python3 --version
python -m pip --version

echo ""
echo "Checking XRDP:"
command -v xrdp
command -v xrdp-sesman

echo ""
echo "Checking XFCE:"
command -v startxfce4

# --------------------------------------------------
# Runtime directories
# --------------------------------------------------

mkdir -p /run/dbus
mkdir -p /run/xrdp
mkdir -p /var/log/xrdp

# --------------------------------------------------
# D-Bus
# --------------------------------------------------

dbus-uuidgen --ensure=/etc/machine-id

dbus-daemon --system --fork || true

# --------------------------------------------------
# Runtime user directory
# --------------------------------------------------

mkdir -p /run/user/0
chmod 700 /run/user/0

export XDG_RUNTIME_DIR=/run/user/0

# --------------------------------------------------
# PulseAudio
# --------------------------------------------------

pulseaudio \
    --system \
    --disallow-exit \
    --disable-shm \
    --exit-idle-time=-1 \
    >/tmp/pulseaudio.log 2>&1 || true

# --------------------------------------------------
# XRDP permissions
# --------------------------------------------------

chown xrdp:xrdp /run/xrdp 2>/dev/null || true

# --------------------------------------------------
# Start XRDP session manager
# --------------------------------------------------

echo ""
echo "Starting xrdp-sesman..."

/usr/sbin/xrdp-sesman &

sleep 2

# --------------------------------------------------
# Start XRDP in foreground
# --------------------------------------------------

echo ""
echo "=========================================="
echo " XRDP SERVER STARTING"
echo " Internal Port: 3389"
echo "=========================================="
echo ""

exec /usr/sbin/xrdp --nodaemon
