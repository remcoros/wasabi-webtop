# Wasabi Webtop

Wasabi Webtop runs [Wasabi Wallet](https://wasabiwallet.io/) in a
[Selkies powered](https://github.com/linuxserver/docker-baseimage-selkies/) Linux desktop that is accessible from a web browser.

Images are published for AMD64.

## Docker

Persist `/config`, allocate at least 1 GB of shared memory, and set a strong
password:

```shell
docker run -d \
  --name wasabi-webtop \
  -e CUSTOM_USER=webtop \
  -e PASSWORD=change-this-password \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=Etc/UTC \
  -p 3000:3000 \
  -p 3001:3001 \
  -v /opt/wasabi-webtop-data:/config \
  --shm-size=1gb \
  --restart unless-stopped \
  ghcr.io/remcoros/wasabi-webtop:latest
```

Open `https://localhost:3001` or `http://localhost:3000`.

The included [`docker-compose.yml`](docker-compose.yml) provides the same
baseline configuration.

## GPU Acceleration

For Intel or AMD GPUs, pass the host DRI devices:

```shell
--device /dev/dri:/dev/dri
```

The Selkies base image automatically uses a single available render node for
hardware video encoding. GPU rendering is enabled unless `DISABLE_DRI3=true`
and `DISABLE_ZINK=true` are set.

For NVIDIA GPUs, install the NVIDIA Container Toolkit and add:

```shell
--runtime nvidia --gpus all
```

For the complete X11 software-rendering path, set:

```shell
-e PIXELFLUX_WAYLAND=false \
-e AUTO_GPU=false \
-e 'SELKIES_USE_CPU=true|locked' \
-e DISABLE_DRI3=true \
-e DISABLE_ZINK=true \
-e LIBGL_ALWAYS_SOFTWARE=true
```

`LIBGL_ALWAYS_SOFTWARE=true` also disables the cosmetic X11 compositor, which
otherwise spams harmless `BadDrawable` and `BadWindow` errors while rendering
Wasabi's frequently changing windows. Turbo mode is enabled by default through
`SELKIES_H264_STREAMING_MODE=true` and remains configurable in the Selkies
sidebar.

## StartOS

The StartOS package is maintained separately in
[wasabi-webtop-startos](https://github.com/remcoros/wasabi-webtop-startos).

# License

[MIT](LICENSE)
