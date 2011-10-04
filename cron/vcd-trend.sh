#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-trend.rb -v2 -l$VCDKIT/logs/vcd-trend.log > /dev/null

