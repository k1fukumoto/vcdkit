#!/bin/sh

VCD=-v2
VC=
VAPP=-aAdmin,Committed%Backup%-%Admin,RESTORETEST01

 rm -frv data/* logs/restore.log && \
  ./vcd-dump.rb $VCD $VC --tree RESTORETEST -l logs/restore.log && \
  ./vcd-report.rb -s -l logs/restore.log && \
  ./vcd-restore.rb -s $VCD --tree RESTORETEST -l logs/restore.log $VAPP && \
  ! grep -e WARN -e ERROR logs/restore.log 

echo TEST RESULT: $?

