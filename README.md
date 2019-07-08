# zfs-snap-backup
BASH scripts for creating and deleting backups of remote servers via rsync and store them as local snapshots on zfs

## Usage howto
* edit `config.sh.def` as `config.sh` you need
* scripts read config.sh or you can override hostnames on cli
* run the script regulary via cron or manualy as `backup.sh [hosntame1] [hostnameN...]`
* you can delete old backups by `delete.sh --all || [hostname1] [hostnameN...]`
