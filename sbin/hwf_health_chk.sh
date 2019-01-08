#!/bin/sh

source /lib/platform.sh
source /lib/functions/hwf_upload_info_routine.sh

HWF_INFO_GATHER_TIME_INTERVAL="120"
HWF_INFO_GATHER_DB_PATH=/tmp/data/hwf_info_gather_db
HWF_INFO_GATHER_TGZ_PATH=/tmp/data/hwf_info_gather_tgz
cause=""
hwf_health_chk_process_list="nginx dnsmasq fcgi-cgi netifd"

hwf_clean_kpanic_tgzs()
{
	local tgzs=""			

	tgzs=$(ls -t $HWF_INFO_GATHER_TGZ_PATH | grep 'kpanic-.*.tgz' | sed '1,4d')

	for tgz in $tgzs; do
		rm -rf $HWF_INFO_GATHER_TGZ_PATH/$tgz
	done
}

hwf_check_panic_log()
{
	local MAC="$(tw_get_mac)"
	local timestamp="$(date +%Y%m%d%H%M%S)"
	local pending_panic_files=""

	mkdir -p $HWF_INFO_GATHER_TGZ_PATH
	[[ $? -ne 0 ]] && return 1

	mkdir -p $HWF_INFO_GATHER_DB_PATH
	[[ $? -ne 0 ]] && return 1

	[[ -e /tmp/data/kpanic.log ]] && {  

		hwf_clean_kpanic_tgzs

		cp /tmp/data/kpanic.log  /tmp/data/kpanic-$MAC-$timestamp.log
		[[ $? -ne 0 ]] && return 1

		cd /tmp/data 
		tar -czf $HWF_INFO_GATHER_TGZ_PATH/kpanic-$MAC-$timestamp.tgz kpanic-$MAC-$timestamp.log
		[[ $? -ne 0 ]] && return 1

		mv /tmp/data/kpanic.log $HWF_INFO_GATHER_DB_PATH
		[[ $? -ne 0 ]] && return 1

		rm /tmp/data/kpanic-$MAC-$timestamp.log 
	}
	
	pending_panic_files=$(ls $HWF_INFO_GATHER_TGZ_PATH | grep "kpanic-.*.tgz")
	if [[ $? -ne 0 ]];then
		return 0
	fi

	for file in $pending_panic_files;do
		hwf_upload_info_data $HWF_INFO_GATHER_TGZ_PATH/$file
	done
}

hwf_clean_coredumps()
{
	local coredumps=""			

	coredumps=$(ls -t /tmp/data | grep '.*\.core\b' | sed '1,4d')

	for core in $coredumps; do
		rm -rf /tmp/data/$core
	done
}

hwf_check_coredump()
{
	ls /tmp/data | grep '.*\.core\b' &> /dev/null	
	[[ $? -eq 0 ]] && { cause=$(ls -t /tmp/data | grep '.*\.core\b' | awk  -F "." 'BEGIN{num=1;str=""}{if (num <= 3 && !match(str, $1)){str=str$1"-";num++}} END{print str"core-"}');return 0;}
	
	return 1
}

hwf_health_chk_process_is_numb_routine()
{
	local chk_command="$1"

	if ! eval $chk_command; then		
		sleep 1
		if ! eval $chk_command; then
			return 0
		fi
	fi

	return 1
}

hwf_health_chk_process_dnsmasq_is_numb()
{
	hwf_health_chk_process_is_numb_routine  'nslookup hwftestdnsmasq.localhost localhost &> /dev/null'

	return $?
}

hwf_helath_chk_process_netifd_is_numb()
{
	hwf_health_chk_process_is_numb_routine  'ubus call network.device status &> /dev/null'

	return $?
}

hwf_health_chk_process_nginx_is_numb()
{
	hwf_health_chk_process_is_numb_routine 'curl -o /dev/null  http://tw/ &> /dev/null'

	return $?
}

hwf_health_chk_process_fcgi_cgi_is_numb()
{
	return 1	
}

hwf_health_chk_process_is_numb()
{
	local process=$1
		
	if hwf_health_chk_process_"${process//-/_}"_is_numb; then
		return 0
	fi
	
	return 1
}

hwf_health_chk_process_is_die()
{
	local target_process=$1

	if ! pidof $target_process > /dev/null; then
		sleep 3
		if ! pidof $target_process > /dev/null; then
			return 0
		fi
	fi

	return 1
}

hwf_health_chk_process()
{
	local process=$1

	if hwf_health_chk_process_is_die $process ; then
		cause=$cause"$process"die-
		return 0
	elif hwf_health_chk_process_is_numb $process ; then
		cause=$cause"$process"numb-
		return 0 
	fi
	
	return 1
}

hwf_health_chk_processes()
{
	cause=""
	local rv=1
	
	hwf_check_coredump 
	if [ $? -eq 0 ];then
		rv=0
	fi

	for process in $hwf_health_chk_process_list; do 
		hwf_health_chk_process $process	
		[[ $? -eq 0 ]] && {
			rv=0
		}
	done

	return $rv
}

hwf_clean_info_tgzs()
{
	local tgzs=""			

	tgzs=$(ls -t $HWF_INFO_GATHER_TGZ_PATH | grep -v 'kpanic-.*.tgz' | sed '1,4d')

	for tgz in $tgzs; do
		rm -rf $HWF_INFO_GATHER_TGZ_PATH/$tgz
	done
}

try_restart_processes()
{
	local process=""	

	for process in $hwf_health_chk_process_list;
	do
		if hwf_health_chk_process $process; then
			case "$process" in
				"nginx")
				/etc/init.d/nginx restart &> /dev/null
				;;
				"netifd")
				/etc/init.d/network restart &> /dev/null
				;;
				"dnsmasq")
				/etc/init.d/dnsmasq restart &> /dev/null
				;;
				"fcgi-cgi")
				/etc/init.d/fcgi-cgi start &> /dev/null
				;;
			esac
		fi
	done
					
}

#Conditions which trigger info-gather
#1. There is kpanic.log in /tmp/data
#2. There is *.core file in /tmp/data
#3. Ether of dnsmasq nginx fcgi-cgi netifd die or didn't response. 
main()
{
	local run_state=""
	local next_stamp="$(date +%s)"

	pid_list=$(pidof "hwf_health_chk.sh")
	instance_num=$(echo $pid_list | wc -w)
	[ "$instance_num" -gt 1 ] && { exit 1; }

	run_state="$(cat /tmp/state/hwf_health_chk_run_state 2> /dev/null )"
	if [[ "$run_state" == "start" ]];then 
		while : ; do

			sleep 10
			
			#Disable by yongming.yang Dec 2, 2014
			#hwf_check_panic_log

			/sbin/diskspace_chk.sh 2000 &> /dev/null

			/sbin/dog_cmagent.sh

			hwf_clean_coredumps

			#hwf_health_chk_processes
			#if [[ $? -eq 0 -a "$(date +%s)" -gt "$next_stamp" ]];then

				hwf_clean_info_tgzs
				
				#Disable by yongming.yang Dec 2, 2014
				#/sbin/hwf_info_gather.sh	$cause "$(date +%Y%m%d%H%M%S)"

				#next_stamp=$(expr $(date +%s) + $HWF_INFO_GATHER_TIME_INTERVAL) 
			#fi

			try_restart_processes
		done
	fi

	#During shutdown, we want hwf_health_chk calm down.
	sleep 1
}

main
