#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-vapp.rb -v2 \
  -D --vdc Admin,'Basic - Admin', -nCBMON \
  -l$VCDKIT/logs/vcd-vapp.log -t -m $VCDKIT/conf/mail/vcd-vapp.xml > /dev/null && \
$VCDKIT/vcd-vapp.rb -v2 \
  -A --vapptemplate Admin,'Basic - Admin',CBMON_TMPL -nCBMON  \
  -l$VCDKIT/logs/vcd-vapp.log -t -m $VCDKIT/conf/mail/vcd-vapp.xml > /dev/null

