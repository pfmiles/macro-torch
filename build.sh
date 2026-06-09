#!/bin/sh

target=SM_Extend.lua

if [ -f "$target" ]; then
    rm $target
fi

# Read build_order.txt line by line, concatenate existing files
# Fault-tolerant mode: silently skip files that don't exist yet (Phase 2-4)
if [ ! -f build_order.txt ]; then
    echo "build_order.txt not found" >&2
    exit 1
fi
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue
    # Skip comment lines
    [ "${line#\#}" != "$line" ] && continue
    # Strict mode: exit with error if any file in build_order.txt doesn't exist
    if [ -f "$line" ]; then
        printf '\n' >> "$target"
        cat "$line" >> "$target"
    else
        echo "ERROR: File not found in build_order.txt: $line" >&2
        exit 1
    fi
done < build_order.txt

# Copy to game directory only on Windows/Cygwin
if [ "$OSTYPE" = "cygwin" ]; then
    cp $target /cygdrive/d/games/TurtleWoW/Interface/AddOns/SuperMacro/
    ## cp $target /cygdrive/d/games/twmoa_1172_cn/Interface/AddOns/SuperMacro/
fi