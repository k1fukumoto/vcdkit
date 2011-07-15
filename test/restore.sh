#!/bin/sh

time ( \
    rm -frv data/vcd-report/restoring && \
    ./vcd-restore.rb -v1 -t$1 -aAdmin,Admin,BACKUPTEST-01 && \
    ./vcd-dump.rb -v1 -aAdmin,Admin,BACKUPTEST-01 -trestoring && \
    ./vcd-report.rb -aAdmin,Admin,BACKUPTEST-01 -trestoring \
)
