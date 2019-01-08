#!/bin/sh


INTERFACE=vpn

install() {
    #add firewall to firewall
    firewall_add $INTERFACE
    return 0
}

uninstall() {
    stop
    rm -f /tmp/dnsmasq.d/pptp && /etc/init.d/dnsmasq restart
    
    uci delete network.$INTERFACE
    uci commit network.$INTERFACE
    
    firewall_del $INTERFACE
    return 0
}

status() {
    ubus call network.interface.$INTERFACE status 2>>/dev/null |grep "up"|grep -qs "true"
    if [ $? -eq 0 ]; then
        stat=running
    else
    	stat=stopped
    fi
    echo -e "$stat\c"
    return 0
}

start() {
    /etc/init.d/xl2tpd start
    ifup $INTERFACE
    return 0
}

stop() {
    ubus call network.interface.$INTERFACE status|grep "up"|grep -qs "true"
    if [ $? -eq 0 ]; then
    	ifdown $INTERFACE
    	sleep 3
    	default=`route | grep default | wc -l`
    	if [ $default -eq "0" ]; then
    	    ifup wan
    	fi
    fi
    /etc/init.d/xl2tpd stop
    return 0
}


firewall_add () {
    while [ 1 ]; do
    	name=`uci get firewall.@zone[$i].name 2>/dev/null`
    	if [ -z "$name" ]; then
            #echo "error ! wan not found"
            echo -e "error\c"
            break
    	fi
    	if [ $name == wan ]; then
            network=`uci get firewall.@zone[$i].network`
            line=`echo "$network" | grep "$1" | wc -l`
            if [ $line -eq 0 ]; then
            	newinterface="$network $1"
            	uci set firewall.@zone[$i].network="$newinterface"
            	uci commit firewall
            else
            	#echo "interface $1 existed"
		,,
            fi
            break
        fi
        i=$(($i+1))
    done
}

firewall_del () {                                             
    if [ "$1" == "wan" ];then                                       
    	break                      
    fi

    while [ 1 ]; do
    	name=`uci get firewall.@zone[$i].name 2>/dev/null`
    	if [ -z "$name" ]; then
            #echo "error ! wan not found"
            echo -e "error\c"
            break
    	fi
    	if [ "$name" == "wan" ]; then
            network=`uci get firewall.@zone[$i].network`
            line=`echo "$network" | grep "$1" | wc -l`
            if [ $line -eq 1 ]; then
                newinterface=`echo "$network" | sed  's/ '"$1"'//g'`
            	uci set firewall.@zone[$i].network="$newinterface"
            	uci commit firewall
	    else
		#echo "interface $1 not exist"
		,,
            fi
            break
        fi
        i=$(($i+1))
    done
}

$1
