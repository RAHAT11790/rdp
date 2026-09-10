#!/bin/bash

set -e

echo "========================================"
echo "        Debian XFCE XRDP Server"
echo "========================================"
echo

# Runtime directories
mkdir -p /run/dbus
mkdir -p /var/run/dbus
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

# Ensure DBus machine ID exists
if [ ! -s /var/lib/dbus/machine-id ]; then
    dbus-uuidgen --ensure=/var/lib/dbus/machine-id
fi

echo "[1/5] Starting DBus..."

if pgrep -x dbus-daemon >/dev/null 2>&1; then
    echo "DBus is already running."
else
    dbus-daemon --system --fork
fi

echo "[2/5] Preparing PulseAudio..."

mkdir -p /run/pulse
chmod 777 /run/pulse

# Start system PulseAudio if available
if command -v pulseaudio >/dev/null 2>&1; then
    pulseaudio \
        --system \
        --disallow-exit \
        --disable-shm \
        --daemonize=yes \
        --exit-idle-time=-1 \
        >/tmp/pulseaudio.log 2>&1 || true
fi

echo "[3/5] Preparing XRDP..."

# Remove stale PID files
rm -f /run/xrdp/xrdp.pid
rm -f /run/xrdp/xrdp-sesman.pid

mkdir -p /run/xrdp
chown xrdp:xrdp /run/xrdp || true

echo "[4/5] Starting XRDP..."

# Start xrdp using Debian's init script
service xrdp start

sleep 2

echo "[5/5] XRDP status:"
echo

if pgrep -x xrdp >/dev/null 2>&1; then
    echo "✓ xrdp is running"
else
    echo "✗ xrdp failed to start"
    echo
    cat /var/log/xrdp.log 2>/dev/null || true
    exit 1
fi

if pgrep -x xrdp-sesman >/dev/null 2>&1; then
    echo "✓ xrdp-sesman is running"
else
    echo "✗ xrdp-sesman failed to start"
    echo
    cat /var/log/xrdp-sesman.log 2>/dev/null || true
    exit 1
fi

echo
echo "========================================"
echo "       XRDP SERVER IS READY"
echo "========================================"
echo
echo "RDP Port : 3389"
echo "Username : root"
echo "Password : root"
echo
echo "Waiting for RDP connections..."
echo

# Keep container alive and show XRDP logs
touch /var/log/xrdp.log
touch /var/log/xrdp-sesman.log

tail -F \
    /var/log/xrdp.log \
    /var/log/xrdp-sesman.log
