#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

# space delimited list of hostnames to backup
HOSTS=(localhost)
# name of the zpool
POOL=zpool
# dir where is zpool mounted
MOUNT_DIR=/mnt/$POOL
# we need this hack to properly handle spaces and symlinks.
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
# global exlude file
EXCLUDE_PATH=$SCRIPTPATH/backup_exclude
# dir for excluding files per hostname - filename is hostname of the backuped server
EXCLUDE_DIR=$SCRIPTPATH/backup_exclude.d
# lock dir to avoid running backups from same machine multiple times
LOCK_DIR=/run/lock/backup
# how many times try to run rsync before backup fails
MAX_RETRIES=3
# this will keep only one backup per day (the latest)
KEEP_DAYS=14
# this will keep all backups (if you backuping more then once a day)
KEEP_ALL_DAYS=7

# debug settings
DEBUG=1
DEBUG_RSYNC=0

# Do not edit below this line
#############################

mkdir -p $LOCK_DIR
[ "$#" -ne 0 ] && HOSTS=("$@")

if tty -s; then
  Blue='\e[01;34m'
  White='\e[01;37m'
  Red='\e[01;31m'
  Green='\e[01;32m'
  Reset='\e[00m'
  DEBUG_RSYNC=1
fi

debug() {
	[ $DEBUG == 1 ] && echo -e "`date` ${Blue}${1}:${Reset} $2${Reset}"
}

for host in ${HOSTS[@]}; do
	lockfile -r 0 $LOCK_DIR/$host || continue
	options=""
	debug "backuping host" "${White}${host}"
	/sbin/zfs create -p $POOL/$host
	[ -r ${EXCLUDE_DIR}/${host} ] && options="$options --exclude-from ${EXCLUDE_DIR}/${host}"
	[ $DEBUG_RSYNC == 1 ] && options="$options -vP --human-readable"
	i=0
	status=255
	while [ $status -ne 0 -a $i -lt $MAX_RETRIES ]; do
		i=$(($i+1))
		debug "rsync loop try" "$i"
		rsync_command="rsync -aAX $options --numeric-ids --exclude-from $EXCLUDE_PATH --delete --hard-links --inplace --delete-excluded $host:/ $MOUNT_DIR/$host"
		debug "rsync command" "$rsync_command"
		$rsync_command
	       	status=$?
		debug "rsync status" "$status"
	done
	debug "rsync loop end" "$i $status"
	if [ $status -eq 0 ]; then
		snap_command="/sbin/zfs snap ${POOL}/${host}@$(date +'%Y-%m-%d-%H:%M:%S')"
		debug "creating snapshot" "$snap_command"
		$snap_command
		touch $MOUNT_DIR/$host/.last_backup
	else
		debug "rsync failed, skipping create snapshot"
	fi
	rem_old="/sbin/zfs list -t snapshot -o name -H |awk -v keep=$(date -d "now -$KEEP_DAYS days" +"%Y%m%d") -F '[ @-]' '/$host/ {date=\$2\$3\$4; count[date]++; snap[date][count[date]]=\$0} END { for (key in count) { if ( key <= keep) { for ( prt in snap[key] ) { print snap[key][prt] }}} }' | xargs -r -n 1 /sbin/zfs destroy"
	debug "deleting all older than $KEEP_DAYS days old" "$rem_old"
	eval $rem_old
	rem_more_old="/sbin/zfs list -t snapshot -o name -H |awk -v keep=$(date -d "now -$KEEP_ALL_DAYS days" +"%Y%m%d") -F '[ @-]' '/$host/ {date=\$2\$3\$4; count[date]++; snap[date][count[date]]=\$0} END { for (key in count) { if (count[key] > 1 && key <= keep) { delete snap[key][count[key]]; for ( prt in snap[key] ) { print snap[key][prt] }}} }' | xargs -r -n 1 /sbin/zfs destroy"
	debug "keep only one snapshot older than $KEEP_ALL_DAYS days per day" "$rem_more_old"
	eval $rem_more_old
	rm -f $LOCK_DIR/$host
done
