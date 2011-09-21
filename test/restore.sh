#!/bin/sh

VCD=-v3
VC=
VAPP=-aAdmin,Admin,RESTORETEST01

 rm -frv data/* logs/restore.log && \
  ./vcd-dump.rb $VCD $VC -t RESTORETEST -l logs/restore.log -V && \
  ./vcd-report.rb -s -l logs/restore.log -V && \
  ./vcd-restore.rb -s $VCD -tRESTORETEST -l logs/restore.log -V $VAPP && \
  ! grep -e WARN -e ERROR logs/restore.log 

echo TEST RESULT: $?

