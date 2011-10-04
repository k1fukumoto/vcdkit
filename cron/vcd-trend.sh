#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-trend.rb -v2 -l$VCDKIT/logs/vcd-trend.log -m $VCDKIT/conf/mail/vcd-trend.xml > /dev/null

