#!/bin/bash
# Copyright (C) 2018 by Tomas Herceg <tth@rfa.cz>
# Released under GNU GPL 3 or later

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

error() {
	echo -e "`date` ${Red}${1}:${Reset} $2${Reset}"
}

if [ -r $SCRIPTPATH/config.sh ]; then
  source $SCRIPTPATH/config.sh
else
  error "config.sh not found" "you can copy default config.sh.def"
  exit 1
fi

# overwrite hosts from config if commandline parameter is used
if [ "$#" -ne 0 ]; then
  if [ "$@" == "-all" ] || [ "$@" == "--all" ]; then
    HOSTS=`zfs list |awk -F'[ /]+' -v pool="$POOL/" '$0 ~ pool {print $2}' | tr '\n' ' '`
    debug "Overwriting HOSTS by all actual backuped servers" "$HOSTS"
  else
    HOSTS=("$@")
    debug "Overwriting HOSTS from commandline parameter" "$HOSTS"
  fi
fi

if [ "$HOSTS" == "" ]; then
  error "HOSTS is empty" "Nothing to do"
  exit 1
fi

mkdir -p $LOCK_DIR
