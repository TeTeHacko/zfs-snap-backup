#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
source $SCRIPTPATH/shared.sh

if ! mountpoint -q $MOUNT_DIR; then
	debug "$MOUNT_DIR is not mounted"
	exit 1
fi

for host in ${HOSTS[@]}; do
	[ -f $LOCK_DIR/$host ] && continue
	touch $LOCK_DIR/$host
	options=""
	debug "backuping host" "${White}${host}"
	[ ! -d $MOUNT_DIR/$host ] && btrfs subvolume create $MOUNT_DIR/$host 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)

	[ -r ${EXCLUDE_DIR}/${host} ] && options="$options --exclude-from ${EXCLUDE_DIR}/${host}"
	[ $DEBUG_RSYNC == 1 ] && options="$options -vP --human-readable"
	i=0
	status=255
	while [ $status -ne 0 -a $i -lt $MAX_RETRIES ]; do
		i=$(($i+1))
		debug "rsync loop try" "$i"
		rsync_command="rsync -aAX $options --bwlimit $BW_LIMIT --numeric-ids --exclude-from $EXCLUDE_PATH --delete --delete-after --ignore-errors --hard-links --inplace $host:/ $MOUNT_DIR/$host"
		debug "rsync command" "$rsync_command"
		$rsync_command 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
		status=$?
		debug "rsync status" "$status"
	done
	debug "rsync loop end" "$i $status"
	if [ $status -eq 0 ]; then
		mkdir -p $MOUNT_DIR/$host/.snapshots
		snap_command="btrfs subvolume snapshot $MOUNT_DIR/$host $MOUNT_DIR/$host/.snapshots/$(date +'%Y-%m-%d-%H:%M:%S')"
		debug "creating snapshot" "$snap_command"
		$snap_command 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
		touch $MOUNT_DIR/$host/.last_backup 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
	else
		debug "rsync failed, skipping create snapshot"
	fi
	rem_old="btrfs subvolume list -st $MOUNT_DIR | gawk -v keep=$(date -d "now -$KEEP_DAYS days" +"%Y%m%d") -F '[\t/]' '/$host/ {date=substr(\$9,1,4) substr(\$9,6,2) substr(\$9,9,2); count[date]++; snap[date][count[date]]=\$9} END { for (key in count) { if ( key <= keep) { for ( prt in snap[key] ) { print snap[key][prt] }}} }' | xargs -r -n 1 -I{} btrfs subvolume delete $MOUNT_DIR/$host/.snapshots/{}"
	debug "deleting all older than $KEEP_DAYS days old" "$rem_old"
	eval $rem_old 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
	rem_more_old="btrfs subvolume list -st $MOUNT_DIR | gawk -v keep=$(date -d "now -$KEEP_ALL_DAYS days" +"%Y%m%d") -F '[\t/]' '/$host/ {date=substr(\$9,1,4) substr(\$9,6,2) substr(\$9,9,2); count[date]++; snap[date][count[date]]=\$9} END { for (key in count) { if (count[key] > 1 && key <= keep) { delete snap[key][count[key]]; for ( prt in snap[key] ) { print snap[key][prt] }}} }' | xargs -r -n 1 -I{} btrfs subvolume delete $MOUNT_DIR/$host/.snapshots/{}"
	debug "keep only one snapshot older than $KEEP_ALL_DAYS days per day" "$rem_more_old"
	eval $rem_more_old 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
	rm -f $LOCK_DIR/$host 2> >(while read line; do echo -e "${Red}${line}${Reset}" >&2; done)
done

# vim: noexpandtab tabstop=2 shiftwidth=2 nowrap
