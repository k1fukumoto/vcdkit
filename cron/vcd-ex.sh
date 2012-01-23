#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-ex.rb -v10.128.9.10,System,vcloud-sc -l$VCDKIT/logs/vcd-ex.log -t -m $VCDKIT/conf/mail/vcd-ex.xml > /dev/null
$VCDKIT/vcd-ex.rb -v10.128.9.12,System,vcloud-sc -l$VCDKIT/logs/vcd-ex.log -t -m $VCDKIT/conf/mail/vcd-ex.xml > /dev/null
# $VCDKIT/vcd-ex.rb -v1 -l$VCDKIT/logs/vcd-ex.log -t -m $VCDKIT/conf/mail/vcd-ex.xml > /dev/null

