FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# --------------------------------------------------
# 32-bit architecture for Wine
# --------------------------------------------------
RUN dpkg --add-architecture i386

# --------------------------------------------------
# Debian repositories
# --------------------------------------------------
RUN printf '%s\n' \
    'deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware' \
    'deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware' \
    'deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware' \
    > /etc/apt/sources.list

# --------------------------------------------------
# Base packages + XFCE + XRDP + Wine
# --------------------------------------------------
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        gcc \
        g++ \
        make \
        wget \
        curl \
        git \
        ca-certificates \
        gnupg \
        nano \
        vim \
        sudo \
        net-tools \
        iproute2 \
        procps \
        psmisc \
        lsof \
        unzip \
        zip \
        xz-utils \
        bzip2 \
        software-properties-common \
        \
        xrdp \
        xfce4 \
        xfce4-goodies \
        xorg \
        xorgxrdp \
        dbus-x11 \
        policykit-1 \
        \
        pulseaudio \
        pulseaudio-utils \
        \
        wine \
        wine32 \
        \
        firefox-esr \
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

# --------------------------------------------------
# Build Python 3.14.7 from official source
# --------------------------------------------------
ARG PYTHON_VERSION=3.14.7

RUN cd /tmp && \
    wget -q https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz && \
    tar -xzf Python-${PYTHON_VERSION}.tgz && \
    cd Python-${PYTHON_VERSION} && \
    ./configure \
        --prefix=/usr/local \
        --enable-optimizations \
        --with-ensurepip=install \
        --enable-shared && \
    make -j"$(nproc)" && \
    make altinstall && \
    ldconfig && \
    cd / && \
    rm -rf /tmp/Python-${PYTHON_VERSION}* && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/python3.14 /usr/local/bin/python && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip3 && \
    ln -sf /usr/local/bin/pip3.14 /usr/local/bin/pip

# --------------------------------------------------
# Verify Python
# --------------------------------------------------
RUN python --version && \
    python3 --version && \
    pip --version

# --------------------------------------------------
# Upgrade pip/setuptools/wheel
# --------------------------------------------------
RUN python -m pip install --upgrade \
    pip \
    setuptools \
    wheel

# --------------------------------------------------
# XRDP configuration
# --------------------------------------------------
RUN adduser xrdp ssl-cert || true

RUN sed -i \
    's/^port=3389/port=3389/' \
    /etc/xrdp/xrdp.ini

# --------------------------------------------------
# XFCE session for XRDP
# --------------------------------------------------
RUN printf '%s\n' \
    '#!/bin/sh' \
    'unset DBUS_SESSION_BUS_ADDRESS' \
    'unset XDG_RUNTIME_DIR' \
    'startxfce4' \
    > /etc/xrdp/startwm.sh && \
    chmod +x /etc/xrdp/startwm.sh

# --------------------------------------------------
# Root user setup
# --------------------------------------------------
RUN echo 'root:root' | chpasswd

# Allow root XRDP login
RUN sed -i 's/^TerminalServerUsers=.*/TerminalServerUsers=tsusers/' /etc/xrdp/sesman.ini || true

# --------------------------------------------------
# Xwrapper
# --------------------------------------------------
RUN mkdir -p /etc/X11 && \
    printf '%s\n' \
    'allowed_users=anybody' \
    'needs_root_rights=yes' \
    > /etc/X11/Xwrapper.config

# --------------------------------------------------
# DBus
# --------------------------------------------------
RUN mkdir -p /var/run/dbus && \
    dbus-uuidgen --ensure=/etc/machine-id && \
    ln -sf /etc/machine-id /var/lib/dbus/machine-id

# --------------------------------------------------
# XFCE root session
# --------------------------------------------------
RUN printf '%s\n' \
    '#!/bin/sh' \
    'startxfce4' \
    > /root/.xsession && \
    chmod +x /root/.xsession

# --------------------------------------------------
# Environment
# --------------------------------------------------
ENV PATH="/usr/local/bin:${PATH}"
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# --------------------------------------------------
# Startup script
# --------------------------------------------------
COPY start.sh /start.sh
RUN chmod +x /start.sh

# --------------------------------------------------
# Railway TCP Proxy / XRDP
# --------------------------------------------------
EXPOSE 3389

# --------------------------------------------------
# Start
# --------------------------------------------------
CMD ["/start.sh"]
