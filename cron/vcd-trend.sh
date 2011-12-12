#!/bin/sh

run() {
  $VCDKIT/vcd-trend.rb -v1 \
  -l$VCDKIT/logs/vcd-trend.log \
  -m $VCDKIT/conf/mail/vcd-trend.xml $*
}

if [ "$SILENT" == "yes" ]; then
    run $* > /dev/null 2>&1
else
    run $*
fi


