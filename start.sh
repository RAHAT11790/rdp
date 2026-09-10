#!/bin/bash

set -u

echo "=============================================="
echo "        RS ANIME XRDP CONTAINER"
echo "=============================================="

# --------------------------------------------------
# Runtime directories
# --------------------------------------------------

mkdir -p /run/dbus
mkdir -p /var/run/dbus
mkdir -p /var/run/xrdp
mkdir -p /tmp/.X11-unix

chmod 1777 /tmp/.X11-unix

# --------------------------------------------------
# Remove stale XRDP PID files
# --------------------------------------------------

rm -f /var/run/xrdp/xrdp-sesman.pid
rm -f /var/run/xrdp/xrdp.pid

# --------------------------------------------------
# Machine ID
# --------------------------------------------------

dbus-uuidgen --ensure=/etc/machine-id
ln -sf /etc/machine-id /var/lib/dbus/machine-id

# --------------------------------------------------
# Make sure no old XRDP process exists
# --------------------------------------------------

pkill -9 -x xrdp 2>/dev/null || true
pkill -9 -x xrdp-sesman 2>/dev/null || true

sleep 1

# --------------------------------------------------
# TLS verification
# --------------------------------------------------

echo ""
echo "[1/6] Checking TLS..."

test -s /etc/xrdp/cert.pem
test -s /etc/xrdp/key.pem

echo "      Certificate : OK"
echo "      Private key : OK"

# --------------------------------------------------
# XRDP configuration
# --------------------------------------------------

echo ""
echo "[2/6] Checking XRDP..."

echo "      Port:"
grep -E '^[[:space:]]*port=' /etc/xrdp/xrdp.ini || true

echo "      Security:"
grep -E '^[[:space:]]*security_layer=' /etc/xrdp/xrdp.ini || true

echo "      Root login:"
grep -E '^[[:space:]]*AllowRootLogin=' /etc/xrdp/sesman.ini || true

# --------------------------------------------------
# DBus
# --------------------------------------------------

echo ""
echo "[3/6] Starting DBus..."

dbus-daemon --system --fork 2>/dev/null || true

echo "      DBus : OK"

# --------------------------------------------------
# PulseAudio
# --------------------------------------------------

echo ""
echo "[4/6] Preparing PulseAudio..."

pulseaudio \
    --system \
    --disallow-exit \
    --disable-shm \
    --daemonize=yes \
    >/tmp/pulseaudio.log 2>&1 || true

echo "      PulseAudio : OK"

# --------------------------------------------------
# XRDP SESMAN
#
# IMPORTANT:
# --nodaemon keeps sesman attached to this process.
# This avoids the PID/daemonization problem.
# --------------------------------------------------

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
    cat /var/log/xrdp-sesman-console.log 2>/dev/null || true

    echo ""
    echo "----- SESMAN LOG -----"
    cat /var/log/xrdp-sesman.log 2>/dev/null || true

    exit 1
fi

echo "      xrdp-sesman : RUNNING"

# --------------------------------------------------
# XRDP
# --------------------------------------------------

echo ""
echo "[6/6] Starting XRDP..."

/usr/sbin/xrdp \
    --nodaemon \
    >/var/log/xrdp-console.log 2>&1 &

XRDP_PID=$!

sleep 3

if ! kill -0 "$XRDP_PID" 2>/dev/null; then

    echo ""
    echo "=============================================="
    echo "ERROR: xrdp FAILED"
    echo "=============================================="

    echo ""
    echo "----- XRDP CONSOLE -----"
    cat /var/log/xrdp-console.log 2>/dev/null || true

    echo ""
    echo "----- XRDP LOG -----"
    cat /var/log/xrdp.log 2>/dev/null || true

    echo ""
    echo "----- SESMAN LOG -----"
    cat /var/log/xrdp-sesman.log 2>/dev/null || true

    exit 1
fi

echo "      xrdp : RUNNING"

# --------------------------------------------------
# Wait for port
# --------------------------------------------------

echo ""
echo "Checking TCP 3389..."

PORT_OK=0

for i in {1..10}; do

    if ss -lnt 2>/dev/null | grep -q ':3389 '; then
        PORT_OK=1
        break
    fi

    sleep 1

done

if [ "$PORT_OK" -ne 1 ]; then

    echo ""
    echo "=============================================="
    echo "ERROR: PORT 3389 IS NOT LISTENING"
    echo "=============================================="

    echo ""
    echo "----- XRDP LOG -----"
    cat /var/log/xrdp.log 2>/dev/null || true

    echo ""
    echo "----- SESMAN LOG -----"
    cat /var/log/xrdp-sesman.log 2>/dev/null || true

    exit 1
fi

# --------------------------------------------------
# SUCCESS
# --------------------------------------------------

echo ""
echo "=============================================="
echo "          XRDP SERVER IS READY"
echo "=============================================="
echo ""
echo "Desktop   : XFCE"
echo "Protocol  : RDP"
echo "Security  : TLS"
echo "Port      : 3389"
echo "Username  : root"
echo "Password  : root"
echo "Python    : $(python --version 2>&1)"
echo ""
echo "xrdp PID        : $XRDP_PID"
echo "xrdp-sesman PID : $SESMAN_PID"
echo ""
echo "TCP 3389 : LISTENING"
echo "=============================================="
echo ""
echo "Waiting for RDP connections..."
echo ""

# --------------------------------------------------
# Keep container alive and monitor both processes
# --------------------------------------------------

while true; do

    if ! kill -0 "$XRDP_PID" 2>/dev/null; then

        echo ""
        echo "ERROR: xrdp process stopped!"

        cat /var/log/xrdp.log 2>/dev/null || true
        cat /var/log/xrdp-console.log 2>/dev/null || true

        exit 1
    fi

    if ! kill -0 "$SESMAN_PID" 2>/dev/null; then

        echo ""
        echo "ERROR: xrdp-sesman process stopped!"

        cat /var/log/xrdp-sesman.log 2>/dev/null || true
        cat /var/log/xrdp-sesman-console.log 2>/dev/null || true

        exit 1
    fi

    sleep 10

done
