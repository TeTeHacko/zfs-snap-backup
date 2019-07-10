#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/shared.sh

for host in ${HOSTS[@]}; do
	lockfile -r 0 $LOCK_DIR/$host || continue
	rem_old="/sbin/zfs list -t snapshot -o name -H |awk -v keep=$(date -d "now -$KEEP_DAYS days" +"%Y%m%d") -F '[ @-]' '/$host/ {date=\$2\$3\$4; count[date]++; snap[date][count[date]]=\$0} END { for (key in count) { if ( key <= keep) { for ( prt in snap[key] ) { print snap[key][prt] }}} }' | xargs -r -n 1 /sbin/zfs destroy"
	debug "deleting all older than $KEEP_DAYS days old" "$rem_old"
	eval $rem_old 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
	rem_more_old="/sbin/zfs list -t snapshot -o name -H |awk -v keep=$(date -d "now -$KEEP_ALL_DAYS days" +"%Y%m%d") -F '[ @-]' '/$host/ {date=\$2\$3\$4; count[date]++; snap[date][count[date]]=\$0} END { for (key in count) { if (count[key] > 1 && key <= keep) { delete snap[key][count[key]]; for ( prt in snap[key] ) { print snap[key][prt] }}} }' | xargs -r -n 1 /sbin/zfs destroy"
	debug "keep only one snapshot older than $KEEP_ALL_DAYS days per day" "$rem_more_old"
	eval $rem_more_old 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
	rm -f $LOCK_DIR/$host 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
done
