# Stable Debian Trixie image with Selkies 2.0.0 and the upstream webcam restart fix.
FROM ghcr.io/linuxserver/baseimage-selkies:debiantrixie-3900c0f0-ls140@sha256:c3f25149cf58957fcc4259904b02cf88b1e51fc8df2f9946bc64650701e527e7 AS buildstage

ARG WASABI_VERSION=2.8.4
ARG WASABI_VERSION_TAG=2.8.4
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
               https://raw.githubusercontent.com/WalletWasabi/WalletWasabi/v${WASABI_VERSION_TAG}/PGP.txt && \
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

# Remove the gallery installer, its startup provisioning and its external catalogue.
COPY strip-proot-apps.sh /tmp/strip-proot-apps.sh
RUN sh /tmp/strip-proot-apps.sh && rm -f /tmp/strip-proot-apps.sh

# start from scratch so we create smaller layers in the resulting image
FROM scratch

COPY --from=buildstage / .

# restore runtime metadata inherited from the Selkies base image
ENV \
  # from https://github.com/linuxserver/docker-baseimage-debian/blob/master/Dockerfile
  HOME="/root" \
  LANGUAGE="en_US.UTF-8" \
  LANG="en_US.UTF-8" \
  TERM="xterm" \
  S6_CMD_WAIT_FOR_SERVICES_MAXTIME="0" \
  S6_VERBOSITY=1 \
  S6_STAGE2_HOOK=/docker-mods \
  VIRTUAL_ENV=/lsiopy \
  PATH="/lsiopy/bin:$PATH" \
  # from https://github.com/linuxserver/docker-baseimage-selkies/blob/master/Dockerfile
  DISPLAY=:1 \
  PERL5LIB=/usr/local/bin \
  HOME=/config \
  START_DOCKER=true \
  PULSE_RUNTIME_PATH=/defaults \
  SHELL=/bin/bash \
  __GL_SYNC_TO_VBLANK=0 \
  SELKIES_INTERPOSER=/usr/lib/selkies_input_interposer.so \
  SELKIES_WEBCAM_INTERPOSER=/usr/lib/selkies_v4l2_interposer.so \
  NVIDIA_DRIVER_CAPABILITIES=all \
  DISABLE_ZINK=false \
  DISABLE_DRI3=false \
  SELKIES_ENCODER="h264enc,jpeg" \
  # nginx handles CUSTOM_USER/PASSWORD authentication in front of Selkies.
  SELKIES_ENABLE_BASIC_AUTH=false \
  SELKIES_ALLOWED_ORIGINS="*" \
  SELKIES_RATE_CONTROL_MODE="crf,cbr" \
  # custom for our image
  START_DOCKER=false \
  GTK_THEME=Adwaita:dark \
  GTK2_RC_FILES=/usr/share/themes/Adwaita-dark/gtk-2.0/gtkrc \
  # Default to change-based encoding at 30 fps; keep both settings adjustable.
  SELKIES_VIDEO_STREAMING_MODE=false \
  SELKIES_FRAMERATE="30,8-120" \
  # The previous WebSocket runtime always resized to the browser, despite its false setting default.
  SELKIES_ENABLE_RESIZE=true \
  SELKIES_ENABLE_RATE_CONTROL=false \
  SELKIES_VIDEO_BITRATE="1000-100000" \
  SELKIES_USE_BROWSER_CURSORS=false \
  SELKIES_ENABLE_BINARY_CLIPBOARD=false \
  SELKIES_AUDIO_ENABLED="false|locked" \
  SELKIES_MICROPHONE_ENABLED="false|locked" \
  # Request browser camera access only while the wallet opens its scanner.
  SELKIES_WEBCAM_ON_START=demand \
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
