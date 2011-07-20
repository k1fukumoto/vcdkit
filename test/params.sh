#!/bin/sh

time ( \
    rm -frv data/vcd-dump/$1 && \
    rm -frv data/vcd-report/$1 && \
    ./vcd-dump.rb -v2 -aVMTest,'Basic - VMTest',BACKUPTEST-01 -t$1 && \
    ./vcd-report.rb -aVMTest,'Basic - VMTest',BACKUPTEST-01 -t$1 \
)
