#!/bin/sh

time ( \
    rm -frv data/vcd-dump/$1 && \
    rm -frv data/vcd-report/$1 && \
    ./vcd-dump.rb -v1 -aAdmin,Admin,$2 -t$1 && \
    ./vcd-report.rb -aAdmin,Admin,$2 -t$1 \
)
