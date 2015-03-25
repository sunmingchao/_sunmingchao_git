#!/bin/bash
memused=`cat /proc/meminfo  |awk '{if($1 == "MemTotal:")total=$2;if($1 == "MemFree:")free=$2;if($1 == "Buffers:")buff=$2;if($1 == "Cached:")cache=$2}END{printf("%0.0f",(total-free-buff-cache)/total * 100)}'`

if [ "$memused" -ge 90 ];then
	echo CRITICAL: mem free is $memused"%"
	exit 2
else
	echo OK: mem free is $memused"%"
	exit 0
fi
