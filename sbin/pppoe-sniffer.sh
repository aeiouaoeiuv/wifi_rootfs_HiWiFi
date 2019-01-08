#/bin/sh

seconds="$1"

killall pppoe-server &> /dev/null

[[ -e "/tmp/pppoe-sniffer" ]] || ( mkdir /tmp/pppoe-sniffer/ )

: > /tmp/pppoe-sniffer/pppoe.key

/usr/sbin/pppoe-sniffer-server -F -I br-lan & 

#time_out="$(( $(date +%s) + seconds ))"
#curr_time="$(date +%s)"

sleep $seconds


killall pppoe-sniffer-server &> /dev/null

