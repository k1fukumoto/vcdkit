#!/bin/sh

time ( \
    ./vcd-restore.rb -v1 -t$1 -aAdmin,Admin,VCDTEST-101 && \
    ./vcd-report.rb -aAdmin,Admin,VCDTEST-101 -trestoring \
)
