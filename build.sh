#!/bin/sh

if [ $# != 1 ]; then
    echo "Usage: $0 eng/chs, to generate English or Chinese version of the resulting SuperMacro extension file."
fi

target=SM_Extend.lua

if [ -f "$target" ]; then
    rm $target
fi

## Unit.lua should be placed first
if [ -f "Unit.lua" ]; then
    cat Unit.lua >> $target
fi
find ./ -iname '*.lua'|grep -v "$target"|grep -v "Unit.lua"|xargs cat >> $target

lang=$1

if [ "$lang" == "eng" ]; then
    IFS=$'\n';for line in $(cat chsEngMapping.txt);
    do
        c=$(echo $line|cut -d '=' -f 1|sed 's/^[ \t]*//;s/[ \t\r\n]*$//')
        e=$(echo $line|cut -d '=' -f 2|sed 's/^[ \t]*//;s/[ \t\r\n]*$//')
        sed -i "s/$c/$e/g" $target
    done
fi

cp $target /cygdrive/d/games/TurtleWoW/Interface/AddOns/SuperMacro/
cp $target /cygdrive/d/games/twmoa_1172_cn/Interface/AddOns/SuperMacro/


