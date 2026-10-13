#!/usr/bin/env bash
# Lock with swaylock-effects when available (blur/clock/fade); plain swaylock otherwise.

if swaylock --help 2>&1 | grep -q -- '--effect-blur'; then
    exec swaylock \
        --screenshots \
        --clock \
        --indicator \
        --indicator-radius 100 \
        --indicator-thickness 7 \
        --effect-blur 7x5 \
        --effect-vignette 0.5:0.5 \
        --ring-color 3b4252 \
        --key-hl-color 880033 \
        --line-color 00000000 \
        --inside-color 00000088 \
        --separator-color 00000000 \
        --grace 2 \
        --fade-in 0.3
fi

exec swaylock \
    --indicator-radius 100 \
    --indicator-thickness 7 \
    --ring-color 3b4252 \
    --key-hl-color 880033 \
    --line-color 00000000 \
    --inside-color 00000088 \
    --separator-color 00000000 \
    --color 000000
