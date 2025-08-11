# Wasabi Webtop container

This image provides a full featured web native Linux desktop experience for [Wasabi wallet](https://wasabiwallet.io/).

Users can access their Wasabi wallet through a web browser, with a responsive and user-friendly interface.

# How to use

Make sure to mount '/config' to a local directory on the host machine for persistent storage (/opt/wasabi-webtop-data in below example).

Example docker command:

    docker run -d -p 3000:3000 -v /opt/wasabi-webtop-data:/config remcoros/wasabi-webtop

# Start9 / StartOS

A version for [StartOS](https://startos.com/) can be found here: [wasabi-webtop-startos](https://github.com/remcoros/wasabi-webtop-startos)

# License

[MIT](LICENSE)