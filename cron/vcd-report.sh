#!/bin/sh

cd /home/vcdadmin/vcdkit

VCDKIT=/opt/vmware/vcdkit

./vcd-report.rb -i$VCDKIT/data/vcd-dump -o$VCDKIT/data/vcd-report -l$VCDKIT/logs/vcd-report.log

