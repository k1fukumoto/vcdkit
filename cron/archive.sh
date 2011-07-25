#!/bin/sh

VCDDATA=/opt/vmware/vcdkit/data

for d in vcd-dump vcd-report
do
  for t in `find $VCDDATA/$d -maxdepth 1 -mindepth 1 -mtime +3 -type d`
  do
    file=`basename $t`
    dir=`dirname $t`
    echo "Creating tar archive: $t"
      tar zcf $dir/$file.tgz -C $dir $file && rm -fr $t
  done
  mv $VCDDATA/$d/*.tgz $VCDDATA/$d/archive
done
