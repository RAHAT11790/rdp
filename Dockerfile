FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Enable 32-bit architecture for Wine32
RUN dpkg --add-architecture i386

# Install XFCE + XRDP + Xorg + Wine32 + Firefox
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xrdp \
        xorgxrdp \
        xfce4 \
        xfce4-goodies \
        xorg \
        dbus-x11 \
        dbus \
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
        pulseaudio-module-x11 \
        pulseaudio-utils \
        wine \
        wine32:i386 \
        firefox-esr \
        ca-certificates \
        locales \
        tzdata \
        xauth \
        x11-xserver-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Generate locale
RUN sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

# Root password
RUN echo "root:root" | chpasswd

# Allow Xorg to work correctly inside the container
RUN mkdir -p /etc/X11 && \
    if [ -f /etc/X11/Xwrapper.config ]; then \
        sed -i 's/^allowed_users=.*/allowed_users=anybody/' /etc/X11/Xwrapper.config; \
    else \
        echo "allowed_users=anybody" > /etc/X11/Xwrapper.config; \
    fi

# Configure XFCE for root RDP session
RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'export XDG_CURRENT_DESKTOP=XFCE' \
    'export XDG_SESSION_DESKTOP=xfce' \
    'export DESKTOP_SESSION=xfce' \
    'exec startxfce4' \
    > /root/.xsession && \
    chmod 755 /root/.xsession

# Configure XRDP to start XFCE
RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'export XDG_CURRENT_DESKTOP=XFCE' \
    'export XDG_SESSION_DESKTOP=xfce' \
    'export DESKTOP_SESSION=xfce' \
    'exec startxfce4' \
    > /etc/xrdp/startwm.sh && \
    chmod 755 /etc/xrdp/startwm.sh

# XRDP needs access to ssl-cert
RUN adduser xrdp ssl-cert || true

# Create DBus machine ID
RUN mkdir -p /var/run/dbus /run/dbus && \
    rm -f /var/lib/dbus/machine-id && \
    dbus-uuidgen --ensure=/var/lib/dbus/machine-id

# Make sure XRDP listens on TCP 3389
RUN sed -i 's/^port=.*/port=3389/' /etc/xrdp/xrdp.ini

# Keep standard RDP compatibility
RUN sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini && \
    sed -i 's/^crypt_level=.*/crypt_level=high/' /etc/xrdp/xrdp.ini

# Disable Wayland if present
RUN mkdir -p /etc/gdm3 && \
    printf '[daemon]\nWaylandEnable=false\n' > /etc/gdm3/custom.conf

# Startup script
COPY start.sh /start.sh
RUN chmod 755 /start.sh

# RDP port
EXPOSE 3389

CMD ["/start.sh"]
