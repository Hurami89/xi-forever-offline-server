#!/bin/sh
# Runs the three hardcore tests. They load hardcore.lua from the folder they run in and write stand-in files under
# modules/custom/lua/ there, so this copies everything to an empty folder first: never run them in the server folder.
#   sh run.sh <server folder>          (needs luajit)
SERVER="$1"
[ -n "$SERVER" ] || { echo "usage: sh run.sh <server folder>"; exit 2; }
WORK=$(mktemp -d) || exit 2
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/modules/custom/lua"
cp "$SERVER/modules/custom/late/hardcore.lua" "$SERVER"/modules/custom/tests/hardcore/hardcore_*.lua "$WORK/" || exit 2
cd "$WORK" || exit 2
fail=0
for t in hardcore_test hardcore_random_test hardcore_round4_test; do
    rm -f modules/custom/lua/hardcore_out.txt modules/custom/lua/hardcore_in.txt modules/custom/lua/hardcore_profiles.lua
    # the world's own settings and the launcher's list of characters waiting to become hardcore, as the tests expect them
    printf "return { world = 'Test World', share = true, hub = true }\n" > modules/custom/lua/hardcore_world.lua
    printf "return { { name = 'Ironhide', mode = 1 }, { name = 'Steely', mode = 2 }, { name = 'Silvia', mode = 3 }, { name = 'Leveled', mode = 1 } }\n" > modules/custom/lua/hardcore_pending.lua
    if luajit "$t.lua" > "$t.out" 2>&1; then
        echo "ok    $t ($(grep -c '^ok' "$t.out") checks)"
    else
        fail=1
        echo "FAIL  $t ($(grep -c '^ok' "$t.out") checks passed before it stopped)"
        grep -v '^ok' "$t.out" | head -5
    fi
done
exit $fail
