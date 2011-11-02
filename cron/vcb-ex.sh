#!/bin/sh

export LD_LIBRARY_PATH=/usr/lib/oracle/11.2/client64/lib
export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcb-ex.rb --chargeback_db 2 \
  --vcddc CGSdhv-868,CGSdhv-869 \
  -l$VCDKIT/logs/vcb-ex.log -t -m $VCDKIT/conf/mail/vcb-ex.xml > /dev/null

