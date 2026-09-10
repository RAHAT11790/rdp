FROM python:3.11-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Enable 32-bit architecture for Wine
RUN dpkg --add-architecture i386

# Install XRDP + XFCE + Wine + Firefox + PulseAudio
RUN apt-get update && apt-get install -y --no-install-recommends \
    xrdp \
    xorgxrdp \
    xfce4 \
    xfce4-goodies \
    xorg \
    dbus \
    dbus-x11 \
    sudo \
    curl \
    wget \
    nano \
    net-tools \
    iproute2 \
    procps \
    psmisc \
    policykit-1 \
    pulseaudio \
    pulseaudio-utils \
    wine \
    wine32:i386 \
    firefox-esr \
    ca-certificates \
    locales \
    tzdata \
    xauth \
    x11-xserver-utils \
    openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Generate UTF-8 locale
RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen

# Root password
RUN echo "root:root" | chpasswd

# X11 configuration
RUN mkdir -p /tmp/.X11-unix \
    && chmod 1777 /tmp/.X11-unix

# XFCE session for root
RUN echo "startxfce4" > /root/.xsession \
    && chmod 700 /root/.xsession

# XRDP startup script
RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'exec startxfce4' \
    > /etc/xrdp/startwm.sh \
    && chmod +x /etc/xrdp/startwm.sh

# Allow XRDP user to access TLS private key
RUN adduser xrdp ssl-cert || true

# ---------------------------------------------------------
# XRDP CONFIGURATION
# IMPORTANT:
# Use TLS instead of legacy RDP security.
# This fixes:
# MAC checksum error for non-FIPS PDU
# ---------------------------------------------------------

RUN awk '\
BEGIN { inserted=0 } \
/^\[Globals\]/ { \
    print; \
    print "port=3389"; \
    print "security_layer=tls"; \
    inserted=1; \
    next \
} \
/^[[:space:]]*port[[:space:]]*=/ { next } \
/^[[:space:]]*security_layer[[:space:]]*=/ { next } \
{ print } \
END { if (!inserted) exit 1 }' \
/etc/xrdp/xrdp.ini > /tmp/xrdp.ini \
&& mv /tmp/xrdp.ini /etc/xrdp/xrdp.ini

# ---------------------------------------------------------
# Create a dedicated self-signed TLS certificate
# ---------------------------------------------------------

RUN rm -f /etc/xrdp/cert.pem /etc/xrdp/key.pem \
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

# Make sure XRDP can read the TLS key
RUN id xrdp \
    && id xrdp | grep -q ssl-cert \
    && test -s /etc/xrdp/cert.pem \
    && test -s /etc/xrdp/key.pem

# DBus machine ID
RUN mkdir -p /var/run/dbus \
    && dbus-uuidgen --ensure=/etc/machine-id \
    && ln -sf /etc/machine-id /var/lib/dbus/machine-id

# XRDP port
EXPOSE 3389

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]
