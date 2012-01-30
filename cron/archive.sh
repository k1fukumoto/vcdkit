#!/bin/sh

export VCDDATA=$VCDKIT/data

archive() {
    tooldir=$1
    days=$2

    [ ! -e "$VCDDATA/$tooldir/archive" ] && mkdir "$VCDDATA/$tooldir/archive"
    for t in `find $VCDDATA/$tooldir -maxdepth 1 -mindepth 1 -mtime +$days -type d -a \! -name archive`
    do
	file=`basename $t`
	dir=`dirname $t`
	echo "Creating tar archive: $t"
        tar zcf $dir/$file.tgz -C $dir $file && \
            mv $dir/$file.tgz $VCDDATA/$tooldir/archive && \
            rm -fr $t
    done
}

# Archive vcd-dump data which is older than 7 days
archive vcd-dump 7
# Archive vcd-report data which is older than 31 days
archive vcd-report 31

