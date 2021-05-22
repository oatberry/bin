#!/usr/bin/env bash

# set -euo pipefail

exec rofi -dmenu -i -scroll-method 1 -font 'Iosevka 15' -p "$1"
