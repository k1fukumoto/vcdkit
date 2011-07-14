#!/bin/sh

VCDKIT=/opt/vmware/vcdkit
cd /home/vcdadmin/vcdkit

./vcd-dump.rb -v2 -c2 -d$VCDKIT/data/vcd-dump -l$VCDKIT/logs/vcd-dump.log

