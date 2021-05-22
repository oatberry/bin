#!/usr/bin/env bash

# a maim and pb wrapper

set -eux

declare -a GRIMARGS
DATE="$(date -Isec)"
FORMAT="png"
FILE=~/media/images/scrot/$DATE.$FORMAT
UPLOAD=false

while getopts :sp opt; do
    case $opt in
        s) GRIMARGS+=("-g" "$(slurpe)") ;;
        p) UPLOAD=true ;;
        *) ;;
    esac
done

sleep 1
grim "${GRIMARGS[@]}" -t "$FORMAT" "$FILE"

if [[ $UPLOAD == true ]]; then
    notify-send "mkscrot" "uploading..."

    URL="$(fb "$FILE")${FORMAT}"
    # URL="$(scpaste "$FILE")"
    wl-copy --trim-newline "$URL"
    qutebrowser "$URL"

    notify-send "link ready" "$(wl-paste)"
else
    notify-send "mkscrot" "screenshot taken\n$FILE"
    wl-copy --trim-newline "$FILE"
    imv "$FILE"
fi
