FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

# 1. Enable 32-bit architecture for Wine
RUN dpkg --add-architecture i386

# 2. Force repositories to use the static archive mirrors to bypass expiration errors
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
    sed -i '/debian-security/d' /etc/apt/sources.list

# 3. Update and install packages cleanly using apt-get with bypass flags
RUN apt-get update -o Acquire::Check-Valid-Until=false -o Acquire::Check-Date=false && \
    apt-get install -y --no-install-recommends \
    xrdp \
    xfce4 \
    xfce4-goodies \
    xorg \
    dbus-x11 \
    sudo \
    curl \
    wget \
    nano \
    net-tools \
    policykit-1 \
    pulseaudio \
    pulseaudio-utils \
    wine \
    wine32 \
    firefox-esr && \
    apt-get clean && rm -rf /var/lib/apt/lists/*
