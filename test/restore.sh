#!/bin/sh

rm -frv data/* logs/restore.log && \
  ./vcd-dump.rb -v3 -t RESTORETEST -l logs/restore.log -V && \
  ./vcd-report.rb -s -l logs/restore.log -V && \
  ./vcd-restore.rb -s -v3 -tRESTORETEST -l logs/restore.log -V \
    -aAdmin,Admin,RESTORETEST01 && \
  ! grep -e WARN -e ERROR logs/restore.log && 

echo TEST RESULT: $?

