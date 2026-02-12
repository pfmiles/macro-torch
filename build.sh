#!/bin/sh

target=SM_Extend.lua

if [ -f "$target" ]; then
    rm $target
fi

## macro_torch.lua should be placed first
if [ -f "macro_torch.lua" ]; then
    cat macro_torch.lua >> $target
fi

## impl_util.lua should be placed second
if [ -f "impl_util.lua" ]; then
    cat impl_util.lua >> $target
fi

## then interface_debug.lua
if [ -f "interface_debug.lua" ]; then
    cat interface_debug.lua >> $target
fi

## then Unit.lua
if [ -f "Unit.lua" ]; then
    cat Unit.lua >> $target
fi

find ./ -iname '*.lua'|grep -v "$target"|grep -v "Unit.lua"|grep -v "macro_torch.lua"|grep -v "impl_util.lua"|grep -v "interface_debug.lua"|xargs cat >> $target

# Copy to game directory only on Windows/Cygwin
if [[ "$OSTYPE" == "cygwin" ]]; then
    cp $target /cygdrive/d/games/TurtleWoW/Interface/AddOns/SuperMacro/
    ## cp $target /cygdrive/d/games/twmoa_1172_cn/Interface/AddOns/SuperMacro/
fi


