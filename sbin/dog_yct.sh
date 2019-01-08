#!/bin/sh

if [ "$(uci get firewall.nginx_nat)" == "redirect" ] ; then
	NGINX=1
	HAPROXY=1

	if [ -f /var/run/nginx.pid ] ; then
		if [ -d "/proc/`cat /var/run/nginx.pid`" ] ; then
			NGINX=0
		fi
	fi

	if [ -f /var/run/haproxy.pid ] ; then
		if [ -d "/proc/`cat /var/run/haproxy.pid`" ] ; then
			HAPROXY=0
		fi
	fi

	if [ $NGINX == 1 ] ; then
		/etc/init.d/nginx start
	fi

	if [ $HAPROXY == 1 ] ; then
		/etc/init.d/haproxy start
	fi
fi
