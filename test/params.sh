#!/bin/sh

#VAPP="Admin,Admin,VCDTEST-101"
time (rm -frv data/vcd-dump/$1 && ./vcd-dump.rb -aCustomerDemo-06,"Basic - Customer Demo-06",BACKUPTEST-01 -t$1 && ./vcd-report.rb -aCustomerDemo-06,"Basic - Customer Demo-06",BACKUPTEST-01)
