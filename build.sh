#!/bin/sh

target=SM_Extend.lua

if [ -f "$target" ]; then
    rm $target
fi

find ./ -iname '*.lua'|xargs cat >> $target
