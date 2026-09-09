FROM debian:bullseye

ENV DEBIAN_FRONTEND=noninteractive

RUN dpkg --add-architecture i386

# ১. সরাসরি মেটাডেটা চেক বন্ধ করার কনফিগারেশন তৈরি (Double-layer fix)
RUN echo "Acquire::Check-Valid-Until \"false\";" > /etc/apt/apt.conf.d/99no-check-valid-until \
    && echo "Acquire::Check-Date \"false\";" >> /etc/apt/apt.conf.d/99no-check-valid-until

# ২. রেলওয়ের বিল্ড ইঞ্জিনের জন্য আপডেট কমান্ডের ভেতরেই সরাসরি ফ্ল্যাগ পাস করা হলো
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
