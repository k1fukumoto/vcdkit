#!/bin/sh

time ( \
    rm -frv data/vcd-report/RESTORE && \
    ./vcd-restore.rb -v1 -t$1 -aAdmin,Admin,$2 \
)
