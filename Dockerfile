FROM python:3.11-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# =========================================================
# 32-bit support for Wine
# =========================================================

RUN dpkg --add-architecture i386

# =========================================================
# Install desktop + XRDP + Xorg + DBus + Wine + Firefox
# =========================================================

RUN apt-get update && apt-get install -y --no-install-recommends \
    xrdp \
    xorgxrdp \
    xserver-xorg-core \
    xserver-xorg-input-all \
    xserver-xorg-video-all \
    xfce4 \
    xfce4-goodies \
    xfce4-session \
    xfwm4 \
    xfdesktop4 \
    thunar \
    dbus \
    dbus-x11 \
    dbus-user-session \
    policykit-1 \
    sudo \
    xauth \
    x11-xserver-utils \
    x11-utils \
    xterm \
    xfonts-base \
    xfonts-75dpi \
    xfonts-100dpi \
    fonts-dejavu \
    fonts-liberation \
    locales \
    tzdata \
    ca-certificates \
    curl \
    wget \
    nano \
    net-tools \
    iproute2 \
    procps \
    psmisc \
    openssl \
    pulseaudio \
    pulseaudio-utils \
    firefox-esr \
    wine \
    wine32:i386 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# =========================================================
# Locale
# =========================================================

RUN sed -i \
    's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
    /etc/locale.gen \
    && locale-gen en_US.UTF-8 \
    && update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# =========================================================
# Root password
# =========================================================

RUN echo "root:root" | chpasswd

# =========================================================
# Runtime directories
# =========================================================

RUN mkdir -p \
    /run/dbus \
    /var/run/dbus \
    /var/run/xrdp \
    /tmp/.X11-unix \
    /root/.config \
    /root/.cache \
    /root/.local/share \
    /root/.local/state \
    && chmod 1777 /tmp/.X11-unix

# =========================================================
# XRDP permissions
# =========================================================

RUN adduser xrdp ssl-cert || true

# =========================================================
# Allow root login through XRDP
# =========================================================

RUN sed -i \
    's/^[[:space:]]*AllowRootLogin=.*/AllowRootLogin=true/' \
    /etc/xrdp/sesman.ini

# =========================================================
# Clean XRDP configuration
#
# Remove ALL existing port/security/crypt directives first.
# This prevents:
#
# port=3389
# port=-1
# port=-1
# port=ask3389
#
# =========================================================

RUN sed -i \
    -e '/^[[:space:]]*port[[:space:]]*=/d' \
    -e '/^[[:space:]]*security_layer[[:space:]]*=/d' \
    -e '/^[[:space:]]*crypt_level[[:space:]]*=/d' \
    /etc/xrdp/xrdp.ini \
    && sed -i \
    '/^\[Globals\]/a port=3389\nsecurity_layer=tls\ncrypt_level=high' \
    /etc/xrdp/xrdp.ini

# =========================================================
# Generate XRDP TLS certificate
# =========================================================

RUN rm -f \
    /etc/xrdp/cert.pem \
    /etc/xrdp/key.pem \
    && openssl req \
        -x509 \
        -nodes \
        -newkey rsa:2048 \
        -keyout /etc/xrdp/key.pem \
        -out /etc/xrdp/cert.pem \
        -days 3650 \
        -subj "/C=BD/ST=Dhaka/L=Dhaka/O=RS-ANIME/CN=localhost" \
    && chown root:ssl-cert /etc/xrdp/key.pem \
    && chmod 640 /etc/xrdp/key.pem \
    && chown root:root /etc/xrdp/cert.pem \
    && chmod 644 /etc/xrdp/cert.pem

# =========================================================
# Disable XFCE compositor
#
# Helps avoid rendering problems in virtual XRDP sessions.
# =========================================================

RUN mkdir -p \
    /root/.config/xfce4/xfconf/xfce-perchannel-xml

RUN cat > \
    /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml \
    <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>

<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="use_compositing" type="bool" value="false"/>
  </property>
</channel>
EOF

# =========================================================
# XRDP session startup
# =========================================================

RUN cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh

# Load environment
if [ -r /etc/profile ]; then
    . /etc/profile
fi

if [ -r /etc/default/locale ]; then
    . /etc/default/locale
fi

# Remove conflicting session variables
unset DBUS_SESSION_BUS_ADDRESS
unset WAYLAND_DISPLAY
unset SESSION_MANAGER

# XFCE / X11
export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce

export XDG_CONFIG_DIRS=/etc/xdg/xdg-xfce:/etc/xdg
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/local/share:/usr/share

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Software rendering
export LIBGL_ALWAYS_SOFTWARE=1

# X11
mkdir -p /tmp/.X11-unix
chmod 1777 /tmp/.X11-unix

# Root X11 authority files
touch /root/.Xauthority
touch /root/.ICEauthority

chmod 600 /root/.Xauthority
chmod 600 /root/.ICEauthority

chown root:root /root/.Xauthority
chown root:root /root/.ICEauthority

# Start XFCE inside its own DBus session.
exec dbus-launch --exit-with-session /usr/bin/xfce4-session
EOF

RUN chmod +x /etc/xrdp/startwm.sh

# =========================================================
# Root .xsession fallback
# =========================================================

RUN cat > /root/.xsession <<'EOF'
#!/bin/sh

unset DBUS_SESSION_BUS_ADDRESS
unset WAYLAND_DISPLAY
unset SESSION_MANAGER

export XDG_SESSION_TYPE=x11
export XDG_CURRENT_DESKTOP=XFCE
export XDG_SESSION_DESKTOP=xfce

export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

export LIBGL_ALWAYS_SOFTWARE=1

exec dbus-launch --exit-with-session /usr/bin/xfce4-session
EOF

RUN chmod 700 /root/.xsession

# =========================================================
# DBus machine ID
# =========================================================

RUN dbus-uuidgen --ensure=/etc/machine-id \
    && ln -sf /etc/machine-id /var/lib/dbus/machine-id

# =========================================================
# BUILD-TIME VALIDATION
# =========================================================

RUN test -x /usr/sbin/xrdp \
    && test -x /usr/sbin/xrdp-sesman \
    && test -x /usr/bin/xfce4-session \
    && test -x /usr/bin/dbus-launch \
    && test -s /etc/xrdp/cert.pem \
    && test -s /etc/xrdp/key.pem \
    && id xrdp \
    && id xrdp | grep -q ssl-cert

# =========================================================
# Verify XRDP configuration
# =========================================================

RUN echo "========== XRDP CONFIG ==========" \
    && grep -E '^[[:space:]]*(port|security_layer|crypt_level)=' \
       /etc/xrdp/xrdp.ini \
    && echo "================================="

# =========================================================
# Railway TCP Proxy target
# =========================================================

EXPOSE 3389

# =========================================================
# Startup
# =========================================================

COPY start.sh /start.sh

RUN chmod +x /start.sh

CMD ["/start.sh"]
