#!/bin/sh

is_bridge=`lua -e 'local net=require "luci.controller.api.network";print(net.is_bridge())'`
if [ "$is_bridge" == "true" ] ; then
	PROTO=bridge
else
	PROTO=`uci get network.wan.proto`
fi

WIFI_ENCRYPTION=`uci get wireless.@wifi-iface[0].encryption`

if fgrep -qs 'root:$1$F8LzXJ6/$sZDkHWrZGsbGbOyxim7eh/:' /etc/shadow; then
	ORIGIN_PWD=1
else
	ORIGIN_PWD=0
fi

#LINE=`e2fsck -n /dev/sda 2>&1|wc -l`
LINE=`dmesg| grep -i 'EXT4-fs error' |wc -l`

STORAGE_ERROR=0
[ "$LINE" -gt 0 ] && STORAGE_ERROR=1

# {"proto":"$PROTO", "wifi_encryption":"$WIFI_ENCRYPTION", "origin_pwd":"$ORIGIN_PWD", "storage_error":"$STORAGE_ERROR"}
cat << EOF
{"pr":"$PROTO", "we":"$WIFI_ENCRYPTION", "op":"$ORIGIN_PWD", "se":"$STORAGE_ERROR"}
EOF
