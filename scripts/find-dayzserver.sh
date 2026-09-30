#!/bin/sh
# Find the DayZ Server (Steam app 223350) installed by the local Steam client.
#
# Prints the install directory on stdout and exits 0. Exits 1 with install instructions on
# stderr when no Steam library has it. Nothing is changed; only Steam's own metadata is read:
# every library listed in steamapps/libraryfolders.vdf is checked for appmanifest_223350.acf
# (the manifest is authoritative, the "apps" list in libraryfolders.vdf can lag behind).
#
# Usage: find-dayzserver.sh [-v]   -v also prints build id and install state on stderr
#        find-dayzserver.sh -w     print the DayZ client's workshop directory instead
#                                  (steamapps/workshop/content/221100, one dir per mod id)
# Env:   STEAM_ROOT   check this Steam root first
set -eu

APPID=223350
CLIENT_APPID=221100
verbose=0
workshop=0
case "${1:-}" in
    -v) verbose=1 ;;
    -w) workshop=1 ;;
esac

# Steam roots of the native, Debian/Ubuntu, Flatpak and Snap packages, and macOS.
roots="${STEAM_ROOT:-}
$HOME/.steam/steam
$HOME/.steam/root
$HOME/.steam/debian-installation
$HOME/.local/share/Steam
$HOME/.var/app/com.valvesoftware.Steam/.local/share/Steam
$HOME/snap/steam/common/.local/share/Steam
$HOME/Library/Application Support/Steam"

# vdf_value KEY FILE: the quoted values of every "KEY" "value" line.
vdf_value() {
    sed -n "s/^[[:space:]]*\"$1\"[[:space:]]*\"\(.*\)\"[[:space:]]*\$/\1/p" "$2"
}

libraries=$(
    printf '%s\n' "$roots" | while IFS= read -r root; do
        [ -n "$root" ] && [ -d "$root/steamapps" ] || continue
        (cd "$root" && pwd -P)
        vdf="$root/steamapps/libraryfolders.vdf"
        [ -f "$vdf" ] && vdf_value path "$vdf"
    done | awk '!seen[$0]++'
)

if [ "$workshop" = 1 ]; then
    while IFS= read -r lib; do
        dir="$lib/steamapps/workshop/content/$CLIENT_APPID"
        if [ -f "$lib/steamapps/appmanifest_$CLIENT_APPID.acf" ] && [ -d "$dir" ]; then
            printf '%s\n' "$dir"
            exit 0
        fi
    done <<EOF
$libraries
EOF
    echo "No DayZ workshop items found: install DayZ (app $CLIENT_APPID) and subscribe to the mods" \
        "in the Steam Workshop, then start the DayZ launcher once so Steam downloads them." >&2
    exit 1
fi

found=1
while IFS= read -r lib; do
    manifest="$lib/steamapps/appmanifest_$APPID.acf"
    [ -f "$manifest" ] || continue
    dir="$lib/steamapps/common/$(vdf_value installdir "$manifest" | head -n 1)"
    # StateFlags 4 = fully installed; anything else is downloading, updating or broken.
    state=$(vdf_value StateFlags "$manifest" | head -n 1)
    if [ "$verbose" = 1 ]; then
        echo "manifest:   $manifest" >&2
        echo "buildid:    $(vdf_value buildid "$manifest" | head -n 1)" >&2
        echo "StateFlags: $state" >&2
    fi
    if [ -x "$dir/DayZServer" ] || [ -f "$dir/DayZServer_x64.exe" ]; then
        [ "$state" = 4 ] || echo "warning: StateFlags=$state, Steam has not finished installing/updating it" >&2
        printf '%s\n' "$dir"
        found=0
        break
    fi
done <<EOF
$libraries
EOF

if [ "$found" != 0 ]; then
    cat >&2 <<EOF
DayZ Server (Steam app $APPID) is not installed in any Steam library found:
$(if [ -n "$libraries" ]; then printf '%s\n' "$libraries" | sed 's/^/  /'; else echo "  (no Steam installation found; set STEAM_ROOT if it is elsewhere)"; fi)

Install it with the Steam client (the account must own DayZ): in the Library enable the
"Tools" filter and install "DayZ Server", or open the install dialog with

  steam steam://install/$APPID        (or: xdg-open steam://install/$APPID)

then run this script again.
EOF
fi
exit "$found"
