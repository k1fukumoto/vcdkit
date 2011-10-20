#!/bin/sh

export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcd-vapp.rb -v2 \
  -D --vdc Admin,'Committed Backup - Admin', -nCBMON \
  -l$VCDKIT/logs/vcd-vapp.log -t -m $VCDKIT/conf/mail/vcd-vapp.xml && \
$VCDKIT/vcd-vapp.rb -v2 \
  -A --vapptemplate Admin,'Committed Backup - Admin',CBMON -nCBMON  \
  -l$VCDKIT/logs/vcd-vapp.log -t -m $VCDKIT/conf/mail/vcd-vapp.xml > /dev/null

