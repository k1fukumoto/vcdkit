#!/bin/bash

export VCDKIT=/opt/vmware/vcdkit
files="vsp-datastore.rb"
vcdkit_host=10.149.65.34

#scp $files vcdkit@${vcdkit_host}:$VCDKIT
#ssh vcdkit@${vcdkit_host} "$VCDKIT/vsp-datastore.rb -v 192.168.2.101,System,admin -c 192.168.2.100,Administrator"
ssh vcdkit@${vcdkit_host} "$VCDKIT/vsp-datastore.rb -v 192.168.2.101,System,admin -c 192.168.2.100,Administrator -C $VCDKIT/conf/vsp-datastore.xml -D"
