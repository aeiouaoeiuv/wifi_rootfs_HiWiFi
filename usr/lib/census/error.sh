#!/bin/sh

TWX_ERROR=`cat /tmp/log/nginx/error_twx.log 2>/dev/null | wc -l`

cat << EOF
{"twxe":"$TWX_ERROR"}
EOF
