#!/bin/bash
# wipe any stale screens
#sudo -u minecraft screen -wipe

# First, check if the server is even running. If not, then do nothing and exit.
if screen -ls minecraft/ | grep 'Private\|Attached\|Detached'; then
	echo server active, backing up
	# save the world
	sudo -u minecraft screen -X stuff "say Preparing for server snapshot, world saving disabled. $(printf '\r')"
	sudo -u minecraft screen -X stuff "save-all $(printf '\r')"
	# turn off seever saving
	sudo -u minecraft screen -X stuff "save-off $(printf '\r')"


	if ! mountpoint -q /mnt/btrfs ;then
		echo "btrfs root not mounted, mounting"
		mount /mnt/btrfs
	fi

	# create new snapshot of minecraft directory
	sleep 5 # just in case
	btrfs subvolume snapshot -r /srv/minecraft /mnt/btrfs/backups/minecraft_backup_`date +%F-%H%M%S`
	#umount /mnt/btrfs

	# turn server saving back on
	sudo -u minecraft screen -X stuff "save-on $(printf '\r')"
	sudo -u minecraft screen -X stuff "say Server snapshot complete, world saving enabled. $(printf '\r')"
else
	echo no active server, exiting
	exit
fi

