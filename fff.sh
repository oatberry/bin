#!/bin/bash
#
# fff (fast file finder)

set -euo pipefail
cd || exit 1

PLACES="school media bin downloads misc projects sync .config temp mount"

THING=$(for place in $PLACES; do
            fd --no-ignore --threads 4 --type file "" "$place"
        done | choose.sh "open")

test -n "$THING" && plumb.fnl "$THING"
