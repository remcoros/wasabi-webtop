#!/bin/sh

echo
echo "Initialising Wasabi on Webtop..."
echo

# Copy default files
cp /defaults/.backupignore /config/.backupignore

# always overwrite autostart in case we change it
mkdir -p /config/.config/openbox
cp /defaults/autostart /config/.config/openbox/autostart
chown -R $PUID:$PGID /config/.config/openbox

# set RECONNECT to 1 if it's not defined
if [ -z "$RECONNECT" ]; then
  RECONNECT=1
fi

# add '&reconnect=' setting to kclient html
sed -i "s/\(index\.html?autoconnect=1\)/&\&reconnect=$RECONNECT/" /kclient/public/index.html

exec /init
