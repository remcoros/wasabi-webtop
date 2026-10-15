#!/bin/sh
# Remove the third-party application catalogue rather than relying on the sidebar's
# setting, which arrives only after the browser completes its settings handshake.
# Fail the build if a base-image update moves the files or startup block we remove.
set -eu

CONFIG_RUN=/etc/s6-overlay/s6-rc.d/init-selkies-config/run
CATALOGUE_URL='https://raw.githubusercontent.com/linuxserver/proot-apps/master/metadata/'

# The base copies the installer into persistent home storage and sets BWRAP to a
# helper inside that copy. Remove the complete block, including the BWRAP shim.
grep -q '^# add proot-apps$' "$CONFIG_RUN"
grep -q '^# steam shim$' "$CONFIG_RUN"
before=$(wc -l < "$CONFIG_RUN")
awk '
  /^# add proot-apps$/ { skip = 1 }
  /^# steam shim$/ { skip = 0 }
  !skip { print }
' "$CONFIG_RUN" > "$CONFIG_RUN.new"
mv "$CONFIG_RUN.new" "$CONFIG_RUN"
chmod 755 "$CONFIG_RUN"
removed=$((before - $(wc -l < "$CONFIG_RUN")))
[ "$removed" -ge 20 ] && [ "$removed" -le 40 ] || {
  echo "Expected to remove 20 to 40 proot initialization lines, removed $removed" >&2
  exit 1
}
if grep -qiE 'proot|BWRAP' "$CONFIG_RUN"; then
  echo "Catalogue initialization or BWRAP shim remains in $CONFIG_RUN" >&2
  exit 1
fi
grep -q '^# steam shim$' "$CONFIG_RUN"

test -x /proot-apps/proot-apps
test -x /usr/local/bin/selkies-proot
rm -rf /proot-apps /usr/local/bin/selkies-proot

# Both bundled dashboards can render before the sidebar setting arrives. Keep
# that interval from triggering an external catalogue request, too.
for dashboard in selkies-dashboard selkies-dashboard-wish; do
  assets="/usr/share/selkies/$dashboard/assets"
  bundles=$(grep -rlF "$CATALOGUE_URL" "$assets") || {
    echo "Expected catalogue URL in $assets; inspect the updated dashboard" >&2
    exit 1
  }
  printf '%s\n' "$bundles" | while IFS= read -r bundle; do
    sed -i "s#$CATALOGUE_URL#/proot-apps-removed/#g" "$bundle"
  done
done
if grep -rqF "$CATALOGUE_URL" /usr/share/selkies; then
  echo "External application catalogue URL remains in a dashboard" >&2
  exit 1
fi
