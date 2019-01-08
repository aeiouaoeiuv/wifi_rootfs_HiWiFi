#!/bin/sh

FDISK_CMD_FILE=/tmp/dm-fdisk.cmd
SD_STATE_FILE=/tmp/state/sd_state
SD_LOG_FILE=/tmp/sd-hotplug.log
STORAGE=/tmp/data

sd_log()
{
	echo "$device $@" >>$SD_LOG_FILE
}

sd_state_set()
{
	echo $1 >$SD_STATE_FILE
}

hotplug_cb() {
	sd_log "hotplug_cb $@"

	local action=$1

	for restart_file in /etc/hotplug.d/block/restart.d/* ; do
		$restart_file restart
	done

	for action_file in /etc/hotplug.d/block/action.d/* ; do
		$action_file $action
	done
}

create_storage() {
	sd_log "create_storage $@"

	local dev_mount=$1

	mount | grep "$device" | grep -qs "ro,"
	if [ $? -eq 0 ]; then
		/sbin/sdtest.sh
		return
	fi

	[ ! -L $STORAGE ] && cp -rf $STORAGE/* $dev_mount
	rm -rf $STORAGE
	ln -ns $dev_mount $STORAGE

	[ ! -e $STORAGE/var/lib ] && mkdir -p $STORAGE/var/lib

	/sbin/sdtest.sh

	hotplug_cb start

	sd_state_set "mounted"
}

stop_storage() {
	sd_log "stop_storage $@"

	rm -rf $STORAGE
	mkdir -p $STORAGE

	hotplug_cb stop

	rm -f /tmp/sdinfo.txt

	sd_state_set "umounted"
}

sd_umount()
{
	sd_log "sd_umount"

	local dev_mount=$(mount | grep mmcblk | awk '{print $3}')
	[ "X" != "X$dev_mount" ] && {
		stop_storage
		umount $dev_mount &>/dev/null
		[ $? -ne 0 ] && {
			sd_log "sd_umount $dev_mount failed"
		}
	}

	umount /tmp/cryptdata &>/dev/null
	cryptsetup luksClose cryptdata &>/dev/null
}

sd_part()
{
	sd_log "sd_part $@"

	#TODO#a) If the size is less than 2G, ignore it.

	#b) Clear the old partition table.
	#c) Create two partitions: 1G and Other
cat <<EOF >$FDISK_CMD_FILE
p
o
n
p
1
1
+1024M
n
p
2


p
w
EOF
	fdisk /dev/mmcblk0 <$FDISK_CMD_FILE
	rm -rf $FDISK_CMD_FILE
	sync

	return 0
}

sd_manual_part()
{
	sd_log "sd_manual_part"

	device="[manual]"

	sd_umount 

	sd_part "manual"
}

