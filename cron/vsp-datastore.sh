#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vsp-datastore.rb -v2 -c2 -l$VCDKIT/logs/vsp-datastore.log -C $VCDKIT/conf/vsp-datastore.xml -D -t -m $VCDKIT/conf/mail/vsp-datastore.xml > /dev/null

