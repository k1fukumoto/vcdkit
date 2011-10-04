#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vsp-datastore.rb -c2 -l$VCDKIT/logs/vcd-dump.log -C $VCDKIT/conf/vsp-datastore.xml -D -t -m $VCDKIT/conf/mail/vsp-datastore.xml >/dev/null

