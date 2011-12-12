#!/bin/sh

run() {
    $VCDKIT/vcd-dump.rb -v1 -c1 \
    -l$VCDKIT/logs/vcd-dump.log \
    -t -m $VCDKIT/conf/mail/vcd-dump.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


