#!/bin/sh
#hwf_info_gather is genearted form hwf_proteus.
#The principle of hwf_proteus is to make it as it.
#Hardware resource info
#	CPU	Mem	Net	Disk	Board	
#System info
#

source /lib/platform.sh

HWF_INFO_GATHER_DB_PATH=/tmp/data/hwf_info_gather_db
HWF_INFO_GATHER_DB_STAMP_PATH=""
HWF_INFO_GATHER_CONF=/etc/config/hwf_info_gather.conf
HWF_INFO_GATHER_TGZ_PATH=/tmp/data/hwf_info_gather_tgz

hwf_info_gather_conf()
{
	[[ -d $HWF_INFO_GATHER_CONF ]] || {
	touch $HWF_INFO_GATHER_CONF
	uci set info_gather.conf=conf
	uci commit info_gather
	}
}

#Parse configuration
#Ignore...

hwf_net_info()
{
	#Net
	#Listening sockets
	netstat -lnatup
	#Established connections
	netstat -natup
	#statistics
	#netstat -s
	
	route -n
	iptables -L
	
	ifconfig
}

hwf_cpu_info()
{
	#CPU
	cat /proc/cpuinfo
}

hwf_mem_info()
{
	#Mem info
	cat /proc/meminfo
	free
	cat /proc/ioports
	cat /proc/iomem
}

hwf_disk_info()
{
	#disk
	fdisk -l
	cat /proc/partitions
	cat /proc/mtd
	df -h
	mount
	du -d 1 /
	cat /proc/swaps
}

hwf_board_info()
{
	#cat /proc/pci
	:
}

hwf_host_info()
{
	id
	cat /proc/version
	uptime
	cat /proc/loadavg	
	env				
	#crontab -l
	lsmod
}

#Collect hardware-independent system info
hwf_sys_info()
{
	cd $HWF_INFO_GATHER_DB_STAMP_PATH
	
	dmesg > dmesg.log
	
	hwf_host_info > host.info 
	
	hwf_user_info > user.info 
	
	hwf_net_info > net.info
	
	hwf_disk_info > disk.info
	
	hwf_board_info > board.info
	
	hwf_cpu_info > cpu.info
	
	hwf_mem_info > mem.info
}

#user info
hwf_user_info()
{
	cat /etc/passwd
	cat /etc/group
}

#snapshot /proc
hwf_snapshot_proc()
{
	local entry=""
	
	[[ -d "$HWF_INFO_GATHER_DB_STAMP_PATH/proc" ]] || (mkdir -p "$HWF_INFO_GATHER_DB_STAMP_PATH/proc" )
	
	ps > $HWF_INFO_GATHER_DB_STAMP_PATH/proc/ps.log
	
	e=$(ls /proc)
	for entry in $e
	do
	
		if [[ -d "/proc/$entry" ]];then

			if [[ "$entry" = "slef" ]];then
				continue
			fi

			echo $entry | grep   "^[0-9][0-9]*$" &> /dev/null
			
			if [[ $? -eq "0" ]]; then
				continue
			fi
				#cp -Lr "/proc/$entry"  $HWF_INFO_GATHER_DB_STAMP_PATH/proc &> /dev/null	
		else
			if [[ "$entry" = "kmsg" ]];then
				continue
			fi
	
			cp -Lr "/proc/$entry" $HWF_INFO_GATHER_DB_STAMP_PATH/proc	&> /dev/null
		fi
	done
}

hwf_gather_etc_syslog_core()
{
	cd $HWF_INFO_GATHER_DB_STAMP_PATH
	tar -czf etc.tgz -C / etc 2> /dev/null
	
	mkdir $HWF_INFO_GATHER_DB_STAMP_PATH/syslog
	cp  /tmp/data/sys_log* $HWF_INFO_GATHER_DB_STAMP_PATH/syslog
	
	#tar -czf $HWF_INFO_GATHER_DB_STAMP_PATH/varrun.tgz -C /var run 2> /dev/null
	
	ls /tmp/data | grep ".*\.core" &> /dev/null
	if [[ $? -eq 0 ]]; then	
		mkdir -p $HWF_INFO_GATHER_DB_STAMP_PATH/cores
		mv /tmp/data/*.core $HWF_INFO_GATHER_DB_STAMP_PATH/cores
	fi
}

hwf_processes_info()
{
	ps
	top -n 1
}

#Collect the utlization of software
hwf_utlization_info()
{
	cd $HWF_INFO_GATHER_DB_STAMP_PATH
	hwf_processes_info > processes.info
}

hwf_generate_tgz()
{
	local stamp_dir="$1"

	[[ -d $HWF_INFO_GATHER_TGZ_PATH ]] || ( mkdir -p $HWF_INFO_GATHER_TGZ_PATH )

	cd $HWF_INFO_GATHER_TGZ_PATH
    tar -czf $stamp_dir.tgz -C $HWF_INFO_GATHER_DB_PATH $stamp_dir 2> /dev/null
}

hwf_pre_info_gather()
{
	local stamp_dir="$1"

	HWF_INFO_GATHER_DB_STAMP_PATH=$HWF_INFO_GATHER_DB_PATH/$stamp_dir

	[[ -d $HWF_INFO_GATHER_DB_PATH ]] || ( rm -f $HWF_INFO_GATHER_DB_PATH; mkdir -p $HWF_INFO_GATHER_DB_PATH )
	( cd $HWF_INFO_GATHER_DB_PATH ; ls  $HWF_INFO_GATHER_DB_PATH | grep -v "kpanic.log" | xargs rm -rf )

	mkdir -p $HWF_INFO_GATHER_DB_STAMP_PATH
}

hwf_post_info_gather()
{
	:	
	#rm -rf $HWF_INFO_GATHER_DB_PATH/*
}

main()
{
	local cause="$1"
	local timestamp="$2"
	local mac="$(tw_get_mac)"

	local stamp_dir=$cause$timestamp"-"$mac


	hwf_pre_info_gather $stamp_dir
	
	hwf_snapshot_proc
	
	hwf_sys_info
	
	hwf_utlization_info 
	
	hwf_gather_etc_syslog_core

	hwf_generate_tgz "$stamp_dir"

	hwf_post_info_gather
}

main  $1 $2
