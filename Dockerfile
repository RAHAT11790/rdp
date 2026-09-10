FROM python:3.13-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# --------------------------------------------------
# Enable 32-bit architecture for Wine
# --------------------------------------------------
RUN dpkg --add-architecture i386

# --------------------------------------------------
# Debian repositories
# --------------------------------------------------
RUN printf '%s\n' \
    'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' \
    'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' \
    'deb http://deb.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' \
    > /etc/apt/sources.list

# --------------------------------------------------
# System packages
# --------------------------------------------------
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xrdp \
        xorgxrdp \
        xorg \
        xfce4 \
        xfce4-goodies \
        dbus \
        dbus-x11 \
        dbus-user-session \
        policykit-1 \
        sudo \
        curl \
        wget \
        nano \
        vim \
        git \
        unzip \
        zip \
        ca-certificates \
        net-tools \
        iproute2 \
        procps \
        psmisc \
        lsof \
        pulseaudio \
        pulseaudio-utils \
        wine \
        wine32 \
        firefox-esr \
        fonts-liberation \
        fonts-dejavu \
        libx11-6 \
        libxext6 \
        libxrender1 \
        libxtst6 \
        libxi6 \
        libxrandr2 \
        libxcursor1 \
        libxinerama1 \
        libglib2.0-0 \
        libnss3 \
        libasound2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# --------------------------------------------------
# Verify Python
# --------------------------------------------------
RUN python --version && \
    python3 --version && \
    python -m pip --version

# Update pip tools
RUN python -m pip install --no-cache-dir \
    --upgrade pip setuptools wheel

# --------------------------------------------------
# XRDP configuration
# --------------------------------------------------
RUN mkdir -p /etc/X11 && \
    printf '%s\n' \
        'allowed_users=anybody' \
        'needs_root_rights=yes' \
        > /etc/X11/Xwrapper.config

# --------------------------------------------------
# XFCE session for XRDP
# --------------------------------------------------
RUN printf '%s\n' \
    '#!/bin/sh' \
    'if test -r /etc/profile; then' \
    '    . /etc/profile' \
    'fi' \
    'if test -r "$HOME/.profile"; then' \
    '    . "$HOME/.profile"' \
    'fi' \
    'export XDG_CURRENT_DESKTOP=XFCE' \
    'export XDG_SESSION_DESKTOP=xfce' \
    'export XDG_CONFIG_DIRS=/etc/xdg/xdg-xfce:/etc/xdg' \
    'export XDG_DATA_DIRS=/usr/share/xfce4:/usr/local/share:/usr/share' \
    'startxfce4' \
    > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# --------------------------------------------------
# Root XFCE session
# --------------------------------------------------
RUN printf '%s\n' \
    '#!/bin/sh' \
    'export XDG_CURRENT_DESKTOP=XFCE' \
    'export XDG_SESSION_DESKTOP=xfce' \
    'startxfce4' \
    > /root/.xsession && \
    chmod +x /root/.xsession

# --------------------------------------------------
# XRDP security/config
# --------------------------------------------------
RUN sed -i 's/^security_layer=.*/security_layer=negotiate/' /etc/xrdp/xrdp.ini && \
    sed -i 's/^crypt_level=.*/crypt_level=high/' /etc/xrdp/xrdp.ini

# --------------------------------------------------
# D-Bus machine ID
# --------------------------------------------------
RUN dbus-uuidgen --ensure=/etc/machine-id

# --------------------------------------------------
# Root password
# --------------------------------------------------
RUN echo 'root:root' | chpasswd

# --------------------------------------------------
# Working directory
# --------------------------------------------------
WORKDIR /root

# --------------------------------------------------
# Startup script
# --------------------------------------------------
COPY start.sh /start.sh

RUN chmod +x /start.sh

# --------------------------------------------------
# Railway TCP Proxy / XRDP port
# --------------------------------------------------
EXPOSE 3389

# --------------------------------------------------
# Start
# --------------------------------------------------
CMD ["/start.sh"]
