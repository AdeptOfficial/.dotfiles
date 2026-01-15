#!/bin/bash
# Cava audio visualizer for EWW
# Outputs Unicode bar characters based on audio levels

cava -p <(cat <<EOF
[general]
framerate = 30
bars = 52
sensitivity = 120

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 7
EOF
) | sed -u 's/;//g;s/0/▁/g;s/1/▂/g;s/2/▃/g;s/3/▄/g;s/4/▅/g;s/5/▆/g;s/6/▇/g;s/7/█/g'
