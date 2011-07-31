#!/bin/sh
for d in `ls -d $VCDKIT/data/vcd-dump/2011*`
do
  if ! [ -f $d/VCenter.xml ]; then
#    rm -frv $d
    echo $d
  fi
done

for d in `ls -d $VCDKIT/data/vcd-report/2011*`
do
  if ! [ -f $d/VMList.xml ]; then
#    rm -frv $d
    echo $d
  fi
done
