#!/bin/sh

echo
echo "Initialising Wasabi on Webtop..."
echo

# Copy default files
cp /defaults/.backupignore /config/.backupignore

# always overwrite autostart in case we change it
mkdir -p /config/.config/openbox
cp /defaults/autostart /config/.config/openbox/autostart
chown -R 1000:1000 /config/.config/openbox

# set default TITLE if it's not defined
if [ -z "$TITLE" ]; then
  export TITLE="Wasabi Wallet"
fi

# set RECONNECT to 1 if it's not defined
if [ -z "$RECONNECT" ]; then
  RECONNECT=1
fi

# add '&reconnect=' setting to kclient html
sed -i "s/\(index\.html?autoconnect=1\)/&\&reconnect=$RECONNECT/" /kclient/public/index.html

exec /init
