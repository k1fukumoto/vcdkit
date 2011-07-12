#!/bin/sh

time ( \
    ./vcd-restore.rb -v1 -t$1 -aAdmin,Admin,VCDTEST-101 \
)
