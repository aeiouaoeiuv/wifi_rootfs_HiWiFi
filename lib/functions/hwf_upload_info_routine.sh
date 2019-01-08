#!/bin/sh

source /usr/share/libubox/jshn.sh
source /lib/platform.sh

hwf_upload_info_data() {

	local MAC=`tw_get_mac`
	local KEY=$(getrouterid_infogather)
	local BOARD=$(cat /proc/cmdline | awk '{print $1}' | awk -F= '{print $2}')
	local VERSION=$(cat /etc/.build )
	local FILE="$1"
	local FILE_MD5=$(md5sum $FILE | awk '{print $1}')
	local answer=""

	answer=$(curl -m 300 -F action=upload -F MAC=$MAC -F KEY=$KEY -F BOARD=$BOARD -F VERSION="$VERSION" -F file=@$FILE -F FILE_MD5=$FILE_MD5  "https://hwf-health-chk.hiwifi.com/index.php" -v -k 2>/dev/null)
	rv="$?"
	if [ "$rv" -eq 0 ]; then
		json_load "$answer" 2>/dev/null
		
		json_get_var code code
		[[ $? -ne 0 ]] && { 
			return 1
		}
		
		[[ "$code" -eq 200 ]] && rm -f $FILE
	else
		logger "hwf_upload_info failed, $File, rv=$rv,answer=$answer."
	fi 
}
