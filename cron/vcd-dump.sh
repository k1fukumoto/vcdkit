#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-dump.rb -v2 -c2 -l$VCDKIT/logs/vcd-dump.log

