#!/bin/sh

run() {
  $VCDKIT/vcd-ex.rb -v1 \
  -l$VCDKIT/logs/vcd-ex.log \
  -t -m $VCDKIT/conf/mail/vcd-ex.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


