#!/bin/sh

run() {
  $VCDKIT/vcd-report.rb \
  -l$VCDKIT/logs/vcd-report.log
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


