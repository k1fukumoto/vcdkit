#!/bin/sh

run() {
  $VCDKIT/vcb-ex.rb --chargeback_db 1 -c 5 \
    --restart_vcddc --vcddc CGSdhv-868,CGSdhv-869 \
    -l $VCDKIT/logs/vcb-ex.log -t -m $VCDKIT/conf/mail/vcb-ex.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi

