#!/bin/sh

run() {
    $VCDKIT/vcd-dump.rb -v 10.149.64.102,System,admin \
    -l$VCDKIT/logs/vcd-dump.log
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi

