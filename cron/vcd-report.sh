#!/bin/sh

cd /home/vcdadmin/vcdkit

VCDKITDATA=/opt/vmware/vcdkit/data

./vcd-report.rb -i$VCDKITDATA/vcd-dump -o$VCDKITDATA/vcd-report

