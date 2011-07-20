#!/bin/sh

time ( \
    rm -frv data/vcd-report/RESTORE && \
    ./vcd-restore.rb -v2 -tBASE -idata/vcd-dump -odata/vcd-report -aVMTest,'Basic - VMTest',BACKUPTEST-01 
)
