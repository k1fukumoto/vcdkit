#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-ex.rb -v2 -l$VCDKIT/logs/vcd-ex.log -t -m $VCDKIT/conf/mail/vcd-ex.xml > /dev/null

