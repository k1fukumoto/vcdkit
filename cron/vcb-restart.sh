#!/bin/sh

export LD_LIBRARY_PATH=/usr/lib/oracle/11.2/client64/lib:/usr/lib/vmware-vix
export VCDKIT=/opt/vmware/vcdkit

run() {
  $VCDKIT/vcb-ex.rb --chargeback_db 1 -c6 \
    --restart_vcddc --vcddc CGSdhv-828,CGSdhv-829 \
    -l $VCDKIT/logs/vcb-ex.log -t -m $VCDKIT/conf/mail/vcb-ex.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi

