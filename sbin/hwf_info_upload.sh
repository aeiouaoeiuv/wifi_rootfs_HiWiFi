#!/bin/sh

source /lib/functions/hwf_upload_info_routine.sh

HWF_INFO_GATHER_TGZ_PATH=/tmp/data/hwf_info_gather_tgz

hwf_upload_info()
{
	[[ ! -e $HWF_INFO_GATHER_TGZ_PATH ]] && { return 1; }

	local files=$(ls -t $HWF_INFO_GATHER_TGZ_PATH  | grep ".*.tgz")

	for file in $files
	do
		#Disable by yongming.yang Dec 2, 2014
		rm -f $HWF_INFO_GATHER_TGZ_PATH/$file
		#hwf_upload_info_data $HWF_INFO_GATHER_TGZ_PATH/$file
    done
}

sleep 30

hwf_upload_info
