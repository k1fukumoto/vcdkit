#!/bin/sh

run() {
  $VCDKIT/vsp-datastore.rb -v1 -c1 \
  -l$VCDKIT/logs/vsp-datastore.log \
  -C $VCDKIT/conf/vsp-datastore.xml -D \
  -t -m $VCDKIT/conf/mail/vsp-datastore.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


