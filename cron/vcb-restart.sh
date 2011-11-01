#!/bin/sh

export LD_LIBRARY_PATH=/usr/lib/oracle/11.2/client64/lib:/usr/lib/vmware-vix
export VCDKIT=/opt/vmware/vcdkit

$VCDKIT/vcb-ex.rb --chargeback_db 2 -c5 --restart_vcddb -l$VCDKIT/logs/vcb-ex.log -t -m $VCDKIT/conf/mail/vcb-ex.xml > /dev/null

