FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie-372bdadb-ls115 AS buildstage

# these are specified in Makefile
ARG ARCH
ARG WASABI_VERSION=2.7.2
ARG WASABI_VERSION_TAG=2.7.2
ARG WASABI_PGP_SIG=856348328949861E

RUN \
  echo "**** install packages ****" && \
  apt-get update && \
  # remove dunst, we use xfce4-notifyd instead
  DEBIAN_FRONTEND=noninteractive \
  apt-get remove -y dunst && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y --no-install-recommends \
    exo-utils \
    mousepad \
    xfce4-terminal \
    tumbler \
    thunar \
    # from 'recommended packages', solves a few warnings
    thunar-archive-plugin \
    librsvg2-common \
    python3-xdg \
    # dark theme
    hsetroot \
    gnome-themes-extra \
    xcompmgr \
    # desktop notifications
    xfce4-notifyd \
    libnotify-bin \
    xclip \
    # other
    polkitd \
    pkexec \
    wget \
    gnupg && \
  # remove unused packages from base image
  DEBIAN_FRONTEND=noninteractive \
  apt-get remove --purge --autoremove -y \
    cmake \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-buildx-plugin \
    docker-compose-plugin \
    firmware-amd-graphics \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    fonts-noto-color-emoji \
    fonts-noto-core \
    fonts-noto-cjk \
    g++ \
    gcc \
    locales-all \
    make && \
  # remove left-over locales and generate en_US.UTF-8 via locale-gen
  rm -rf $(ls -d /usr/share/locale/* | grep -vw /usr/share/locale/en | grep -v locale.alias) && \
  echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
  locale-gen && \
  update-locale LANG=en_US.UTF-8 && \
  # upgrade remaining packages
  DEBIAN_FRONTEND=noninteractive \
  apt-get upgrade -y && \
  echo "**** xfce tweaks ****" && \
  rm -f /etc/xdg/autostart/xscreensaver.desktop && \
  # branding
  echo "Starting Wasabi on Webtop..." > /etc/s6-overlay/s6-rc.d/init-adduser/branding && \
  # cleanup
  echo "**** cleanup ****" && \
  apt-get autoclean && \
  rm -rf \
    /config/.cache \
    /var/lib/apt/lists/* \
    /var/tmp/* \
    /tmp/*

# Wasabi
RUN \
  echo "**** install Wasabi ****" && \
  # Wasabi requires this directory to exist
  mkdir -p /usr/share/desktop-directories/ && \
  # Download and install Wasabi
  wget --quiet https://github.com/WalletWasabi/WalletWasabi/releases/download/v${WASABI_VERSION_TAG}/Wasabi-${WASABI_VERSION}.deb \
               https://github.com/WalletWasabi/WalletWasabi/releases/download/v${WASABI_VERSION_TAG}/Wasabi-${WASABI_VERSION}.deb.asc \
               https://github.com/WalletWasabi/WalletWasabi/releases/download/v${WASABI_VERSION_TAG}/SHA256SUMS.asc \
               https://raw.githubusercontent.com/WalletWasabi/WalletWasabi/master/PGP.txt && \
  # verify pgp and sha signatures
  gpg --import PGP.txt && \
  gpg --status-fd 1 --verify Wasabi-${WASABI_VERSION}.deb.asc | grep -q "GOODSIG ${WASABI_PGP_SIG} zkSNACKs <zksnacks@gmail.com>" || exit 1 && \
  sha256sum --check SHA256SUMS.asc --ignore-missing || exit 1 && \
  DEBIAN_FRONTEND=noninteractive \
  apt-get install -y ./Wasabi-${WASABI_VERSION}.deb && \
  # cleanup
  rm ./Wasabi* ./PGP.txt ./SHA256SUMS.asc && \
  # hack to disable systemd-inhibit, which Wasabi uses for sleep/shutdown detection
  # we don't need it, since we run in a container and don't use systemd or sleep the system.
  # this gets rid of a lot of repeated warning logs
  mv /usr/bin/systemd-inhibit /usr/bin/systemd-inhibit.disabled

# start from scratch so we create smaller layers in the resulting image
FROM scratch

COPY --from=buildstage / .

# restore runtime metadata inherited from the Selkies base image
ENV \
  PATH="/lsiopy/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
  HOME=/config \
  LANGUAGE=en_US.UTF-8 \
  LANG=en_US.UTF-8 \
  TERM=xterm \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME=0 \
  S6_VERBOSITY=1 \
  S6_STAGE2_HOOK=/docker-mods \
  VIRTUAL_ENV=/lsiopy \
  DISPLAY=:1 \
  PERL5LIB=/usr/local/bin \
  START_DOCKER=false \
  PULSE_RUNTIME_PATH=/defaults \
  SELKIES_INTERPOSER=/usr/lib/selkies_joystick_interposer.so \
  NVIDIA_DRIVER_CAPABILITIES=all \
  DISABLE_ZINK=false \
  DISABLE_DRI3=false \
  SELKIES_ENCODER="x264enc,jpeg" \
  GTK_THEME=Adwaita:dark \
  GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc \
  SELKIES_H264_STREAMING_MODE=true \
  SELKIES_UI_SIDEBAR_SHOW_APPS=false \
  SELKIES_UI_SIDEBAR_SHOW_GAMEPADS=false \
  SELKIES_GAMEPAD_ENABLED=false \
  NO_GAMEPAD=true \
  PIXELFLUX_WAYLAND=true \
  NO_FULL=1 \
  AUTO_GPU=true \
  TITLE="Wasabi Wallet"

# add local files
COPY /root /
COPY --chmod=755 ./docker_entrypoint.sh /usr/local/bin/docker_entrypoint.sh
COPY --chmod=664 icon.png /usr/share/selkies/www/icon.png

# ports and volumes
EXPOSE 3000
EXPOSE 3001
VOLUME /config

ENTRYPOINT ["/usr/local/bin/docker_entrypoint.sh"]