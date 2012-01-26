#!/bin/bash

export VCDKIT=/opt/vmware/vcdkit
files="vsp-datastore.rb"

scp $files vcdkit@10.149.64.121:$VCDKIT
#ssh vcdkit@10.149.64.121 "$VCDKIT/vsp-datastore.rb -v 192.168.2.101,System,admin -c 192.168.2.100,Administrator"
ssh vcdkit@10.149.64.121 "$VCDKIT/vsp-datastore.rb -v 192.168.2.101,System,admin -c 192.168.2.100,Administrator -C $VCDKIT/conf/vsp-datastore.xml -D"
