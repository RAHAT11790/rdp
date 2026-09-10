FROM python:3.13-bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# =========================================================
# Enable 32-bit architecture for Wine
# =========================================================

RUN dpkg --add-architecture i386

# =========================================================
# Debian repositories
# =========================================================

RUN printf '%s\n' \
    "deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware" \
    "deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware" \
    "deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware" \
    > /etc/apt/sources.list

# =========================================================
# System packages
# =========================================================

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        xrdp \
        xorgxrdp \
        xorg \
        xfce4 \
        xfce4-goodies \
        dbus-x11 \
        dbus \
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
        \
        pulseaudio \
        pulseaudio-utils \
        \
        wine \
        wine32 \
        \
        firefox-esr \
        \
        fonts-liberation \
        fonts-dejavu \
        \
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
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# =========================================================
# Make sure Python 3.13 is the default
# =========================================================

RUN python --version && \
    python3 --version && \
    python -m pip --version

# =========================================================
# Upgrade pip
# =========================================================

RUN python -m pip install --no-cache-dir --upgrade pip setuptools wheel

# =========================================================
# XRDP user/group configuration
# =========================================================

RUN adduser xrdp ssl-cert || true

# =========================================================
# X11 configuration
# =========================================================

RUN mkdir -p /etc/X11 && \
    printf '%s\n' \
        'allowed_users=anybody' \
        'needs_root_rights=yes' \
        > /etc/X11/Xwrapper.config

# =========================================================
# XRDP configuration
# =========================================================

RUN sed -i 's/^port=.*/port=3389/' /etc/xrdp/xrdp.ini && \
    sed -i 's/^security_layer=.*/security_layer=rdp/' /etc/xrdp/xrdp.ini && \
    sed -i 's/^crypt_level=.*/crypt_level=low/' /etc/xrdp/xrdp.ini

# =========================================================
# XFCE session
# =========================================================

RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'exec startxfce4' \
    > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

RUN printf '%s\n' \
    'startxfce4' \
    > /root/.xsession && \
    chmod +x /root/.xsession

# =========================================================
# DBus machine ID
# =========================================================

RUN mkdir -p /run/dbus && \
    dbus-uuidgen --ensure=/etc/machine-id && \
    ln -sf /etc/machine-id /var/lib/dbus/machine-id

# =========================================================
# Root password
# =========================================================

RUN echo 'root:root' | chpasswd

# =========================================================
# Optional application requirements
# =========================================================

COPY requirements.txt /tmp/requirements.txt

RUN if [ -s /tmp/requirements.txt ]; then \
        python -m pip install --no-cache-dir -r /tmp/requirements.txt; \
    fi && \
    rm -f /tmp/requirements.txt

# =========================================================
# Startup script
# =========================================================

COPY start.sh /start.sh

RUN chmod +x /start.sh

# =========================================================
# Railway TCP Proxy
# =========================================================

EXPOSE 3389

# =========================================================
# Start
# =========================================================

CMD ["/start.sh"]
