#!/bin/bash

set -u

echo "=============================================="
echo "        RS ANIME XRDP CONTAINER"
echo "=============================================="

# =========================================================
# Runtime directories
# =========================================================

mkdir -p \
    /run/dbus \
    /var/run/dbus \
    /var/run/xrdp \
    /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

# =========================================================
# Remove stale PID files
# =========================================================

rm -f /var/run/xrdp/xrdp-sesman.pid
rm -f /var/run/xrdp/xrdp.pid

# =========================================================
# Kill leftover processes
# =========================================================

pkill -9 -x xrdp 2>/dev/null || true
pkill -9 -x xrdp-sesman 2>/dev/null || true

sleep 1

# =========================================================
# Machine ID
# =========================================================

dbus-uuidgen --ensure=/etc/machine-id

ln -sf \
    /etc/machine-id \
    /var/lib/dbus/machine-id

# =========================================================
# TLS
# =========================================================

echo ""
echo "[1/6] Checking TLS..."

if [ ! -s /etc/xrdp/cert.pem ]; then
    echo "ERROR: /etc/xrdp/cert.pem missing"
    exit 1
fi

if [ ! -s /etc/xrdp/key.pem ]; then
    echo "ERROR: /etc/xrdp/key.pem missing"
    exit 1
fi

echo "      Certificate : OK"
echo "      Private key : OK"

# =========================================================
# Configuration
# =========================================================

echo ""
echo "[2/6] Checking XRDP configuration..."

echo "      Port:"
grep -E '^[[:space:]]*port=' \
    /etc/xrdp/xrdp.ini || true

echo "      Security:"
grep -E '^[[:space:]]*security_layer=' \
    /etc/xrdp/xrdp.ini || true

echo "      Root login:"
grep -E '^[[:space:]]*AllowRootLogin=' \
    /etc/xrdp/sesman.ini || true

# =========================================================
# DBus
# =========================================================

echo ""
echo "[3/6] Starting DBus..."

dbus-daemon \
    --system \
    --fork \
    >/tmp/dbus.log 2>&1 || true

echo "      DBus : OK"

# =========================================================
# PulseAudio
# =========================================================

echo ""
echo "[4/6] Preparing PulseAudio..."

pulseaudio \
    --system \
    --disallow-exit \
    --disable-shm \
    --daemonize=yes \
    >/tmp/pulseaudio.log 2>&1 || true

echo "      PulseAudio : OK"

# =========================================================
# XRDP SESMAN
#
# IMPORTANT:
# --nodaemon prevents the PID mismatch problem.
# =========================================================

echo ""
echo "[5/6] Starting XRDP session manager..."

/usr/sbin/xrdp-sesman \
    --nodaemon \
    >/var/log/xrdp-sesman-console.log 2>&1 &

SESMAN_PID=$!

sleep 2

if ! kill -0 "$SESMAN_PID" 2>/dev/null; then

    echo ""
    echo "=============================================="
    echo "ERROR: xrdp-sesman FAILED"
    echo "=============================================="

    echo ""
    echo "----- SESMAN CONSOLE -----"

    cat \
        /var/log/xrdp-sesman-console.log \
        2>/dev/null || true

    echo ""
    echo "----- SESMAN LOG -----"

    cat \
        /var/log/xrdp-sesman.log \
        2>/dev/null || true

    exit 1
fi

echo "      xrdp-sesman : RUNNING"

# =========================================================
# XRDP
# =========================================================

echo ""
echo "[6/6] Starting XRDP..."

exec /usr/sbin/xrdp \
    --nodaemon
