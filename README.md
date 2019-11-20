# zfs-snap-backup
BASH scripts for creating and deleting backups of remote servers via rsync and store them as local snapshots on zfs

## Usage howto
* edit `config.sh.def` as `config.sh` you need
* scripts read config.sh or you can override hostnames on cli
* run the script regulary via cron or manualy as `backup.sh [hosntame1] [hostnameN...]`
* you can delete old backups by `delete.sh --all || [hostname1] [hostnameN...]`

## Secure setup on backuped client
* to /root/.ssh/authorized_keys add backup server key like this:
  `command="/root/rsync",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty,no-user-rc ssh-rsa ...`
* copy rsync script to /root/rsync
