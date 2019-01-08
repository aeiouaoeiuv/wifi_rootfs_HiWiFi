#!/bin/sh

if [ -f /var/run/cmagent.pid ] ; then
  CMAGENT=1
  PID=`cat /var/run/cmagent.pid`
  RUNNING_STR=`grep cmagent /proc/$PID/cmdline 2> /dev/null`
  if [ -n "$RUNNING_STR" ] ; then
    CMAGENT=0
  fi
  if [ $CMAGENT == 1 ]; then
    /etc/init.d/cmagent start
  fi
fi
