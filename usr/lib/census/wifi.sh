#!/bin/sh

STA_COUNT=$(lua -e 'hcwifi = require "hcwifi"; hiwifi_net = require "hiwifi.net";local ifname = hiwifi_net.get_wifi_ifnames(); local rv = hcwifi.get(ifname[1], "stalist"); print(#(rv))')
if [[ $? -ne 0 ]];then
    STA_COUNT=0
fi

cat << EOF
{"sc":"$STA_COUNT"}
EOF
