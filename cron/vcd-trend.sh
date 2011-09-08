#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-trend.rb -v1 -l$VCDKIT/logs/vcd-trend.log

