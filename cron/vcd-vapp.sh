#!/bin/sh

run() {
  $VCDKIT/vcd-vapp.rb -v1 \
    -D --vdc Admin,'Basic - Admin', -nCBMON \
    -l$VCDKIT/logs/vcd-vapp.log -t -m $VCDKIT/conf/mail/vcd-vapp.xml && \
  $VCDKIT/vcd-vapp.rb -v1 \
    -A --vapptemplate Admin,'Basic - Admin',CBMON_TMPL -nCBMON  \
    -l$VCDKIT/logs/vcd-vapp.log -t -m $VCDKIT/conf/mail/vcd-vapp.xml
}

if [ "$SILENT" == "yes" ]; then
    run > /dev/null 2>&1
else
    run
fi


