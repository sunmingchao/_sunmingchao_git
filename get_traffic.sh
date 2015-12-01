#!/bin/bash

#########################################################################
# File:         check_traffic.sh
# Description:  Nagios check plugins to check network interface traffic with SNMP run in Linux.
# Language:     GNU Bourne-Again SHell
# Version:	1.0
# Date:		2014.02.18
# Corp.:	HC
# Author:	sunmch126@126.com
# WWW:		http://www.126.com
# NET-SNMP version:	5.5.
#########################################################################

NORMAL=0
WARNING=1
CRITICAL=2
UNKNOWN=3
TEMPDIR="/tmp"
UNIT="Kbps"
INTERVAL_MAX=3600
INTERVAL_MIN=15
TIME=$(date +%s)
TIME_STEMP=$(date +%F" "%T)
SNMPGET=$(which snmpget)
SNMPWALK=$(which snmpwalk)
DEBUG_LOG="/tmp/check_traffic_debug.log"
Debug="false"
Stat_c="false"
Stat_w="false"

printHelpMessage(){
cat<<helpdoc

Usage:
sh $0 -v SnmpVersion -c CommunityName -H RemoteHost -i InterfaceName -W warningInLow,warningInHigh,warningOutLow,warningOutHigh -C warningInLow,warningInHigh,warningOutLow,warningOutHigh [-K|-M]
	-v	Snmp Version
	-c 	Snmp Community Name
	-H 	Remote Host IP address
	-i	Interface Name
	-W 	Warning Threshold Value
	-C 	Critical Threshold Value
	-K	Using Units as Kbps
	-M	Using Units as Mbps
	-D	Debug Mode is ON
	
sh $0 -v 2c -c public -H 192.168.50.90 -i eth0 -W 10,60,10,60 -C 5,80,5,80 -K -D

helpdoc
}

while getopts :v:c:H:i:W:C:hKMD OPTION;do
	case $OPTION in 
		D)
			Debug="true"
		;;
		K)
			UNIT="Kbps"
		;;
		M)
			UNIT="Mbps"
		;;
		v)
			snmpVersion=$OPTARG
		;;
		c)
			snmpCommunity=$OPTARG
		;;
		H)
			serverIp=$OPTARG
		;;
		i)
			ifName=$OPTARG
		;;
		W)
			warningValue=$OPTARG
			warningInLow=$(echo $warningValue|awk -F "," '{print $1}')
			warningInHigh=$(echo $warningValue|awk -F "," '{print $2}')
			warningOutLow=$(echo $warningValue|awk -F "," '{print $3}')
			warningOutHigh=$(echo $warningValue|awk -F "," '{print $4}')
		;;
		C)
			criticalValue=$OPTARG
			criticalInLow=$(echo $criticalValue|awk -F "," '{print $1}')
			criticalInHigh=$(echo $criticalValue|awk -F "," '{print $2}')
			criticalOutLow=$(echo $criticalValue|awk -F "," '{print $3}')
			criticalOutHigh=$(echo $criticalValue|awk -F "," '{print $4}')
		;;
		h)
			printHelpMessage
			exit $NORMAL
		;;
		*)
			echo "Illegal parameters."
			printHelpMessage
			exit $UNKNOWN
		;;		
	esac

done

dataFile=$TEMPDIR/check_traffic_${serverIp}_${ifName}_hist.dat
/bin/chmod 777 $dataFile
#set -x

transUnit(){
        len=$(length $1)
        if [ $len -ge 4 -a $len -le 6 ];then
                echo $(echo $1 | awk '{printf("%0.2f",$1 / 1024)}') Kbps
        elif [ $len -lt 4 ];then
                echo $1
        elif [ $len -gt 6 -a $len -lt 10 ];then
                echo $(echo $1 | awk '{printf("%0.2f",$1 / 1024 / 1024)}') Mbps
        elif [ $len -ge 10 ];then
                echo $(echo $1 | awk '{printf("%0.2f",$1 / 1024 / 1024 / 1024)}') GB
        fi
}

toDebug(){
	if [ "$Debug" = "true" ]; then
		echo "$*" >> $DEBUG_LOG
	fi
}

#Get interface id from SNMP protocol.
getIfId(){
	ifName2=$1
	ifDes=$($SNMPWALK -v $snmpVersion -c $snmpCommunity $serverIp ifDescr | awk '{if($4 == '"\"$ifName2\""')print $1}')
	ifId=$(echo $ifDes | awk -F"." '{print $2}')
	toDebug $TIME_STEMP server_addr=$serverIp interface_name=$ifName interface_id=$ifId
	echo $ifId
}

#Write realtime traffic data into file on this localhost.
writeCurrentData(){
	ifId=$(getIfId $ifName)
	currTime=$TIME
	currIn=$($SNMPWALK -v $snmpVersion -c $snmpCommunity $serverIp IF-MIB::ifHCInOctets.$ifId | awk '{print $4}')
	currOut=$($SNMPWALK -v $snmpVersion -c $snmpCommunity $serverIp IF-MIB::ifHCOutOctets.$ifId | awk '{print $4}')
	toDebug $TIME_STEMP current_time=$currTime current_traffic_in:$currIn current_traffic_out:$currOut
	echo $currTime" "$currIn" "$currOut > $dataFile
}

#Read history data from file in localhost.
readLastData(){
	if [ -f $dataFile ];then
		lastTime=$(cat $dataFile | awk '{print $1}')
		lastIn=$(cat $dataFile | awk '{print $2}')
		lastOut=$(cat $dataFile | awk '{print $3}')
		toDebug $TIME_STEMP last_time=$lastTime last_traffic_in=$lastIn last_traffic_out=$lastOut
	else
		writeCurrentData
		echo "The first running of this script,nothing got."
		exit $NORMAL
	fi
}

#Compute rate of traffic.
calculateTraffic(){
	readLastData
	writeCurrentData
	let "diffTime = $currTime - $lastTime"
	let "diffIn = $currIn - $lastIn"
	let "diffOut = $currOut - $lastOut"
	toDebug $TIME_STEMP diff_time=$diffTime diff_in=$diffIn diff_out=$diffOut
	comp1=$(echo "$diffTime > $INTERVAL_MAX" | bc)
	comp2=$(echo "$diffTime < $INTERVAL_MIN" | bc)
	if [ $comp1 -eq 1 ];then
		echo "The running interval time must less than defined value: $INTERVAL_MAX s, CheckInterval=${diffTime}s."
		exit $WARNING
	fi
	if [ $comp2 -eq 1 ];then
		echo "The running interval time must greater than defined value: $INTERVAL_MIN s, CheckInterval=${diffTime}s."
		exit $WARNING
	fi
	case $UNIT in
		Kbps)
			rateIn=$(echo $diffIn | awk '{printf("%0.2f",$1 / '"$diffTime"' / 1024 * 8)}')
			rateOut=$(echo $diffOut | awk '{printf("%0.2f",$1 / '"$diffTime"' / 1024 * 8)}')
		;;
		Mbps)
			rateIn=$(echo $diffIn | awk '{printf("%0.2f",$1 / '"$diffTime"' / 1024 / 1024 * 8)}')
			rateOut=$(echo $diffOut | awk '{printf("%0.2f",$1 / '"$diffTime"' / 1024 / 1024 * 8)}')
		;;
	esac
	toDebug $TIME_STEMP rate_in=$rateIn rate_out=$rateOut
	
}

#Start compare and culcalate traffic data.
mainFunction(){
	if [ "$Debug" = "true" ]; then
		echo "Debug mode is on, debug log: $DEBUG_LOG  ."
	fi
	toDebug "========================================== S T A R T  D E B U G =============================================="
	toDebug $TIME_STEMP Inspect Parameters:
	toDebug SNMPGET: $SNMPGET
	toDebug SNMPWALK: $SNMPWALK
	toDebug snmpVersion: $snmpVersion
	toDebug snmpCommunity: $snmpCommunity
	toDebug serverIp: $serverIp
	toDebug ifName: $ifName
	toDebug warningValue: $warningValue
	toDebug warningInLow: $warningInLow
	toDebug warningInHigh: $warningInHigh
	toDebug warningOutLow: $warningOutLow
	toDebug warningOutHigh: $warningOutHigh
	toDebug criticalValue: $criticalValue
	toDebug criticalInLow: $criticalInLow
	toDebug criticalInHigh: $criticalInHigh
	toDebug criticalOutLow: $criticalOutLow
	toDebug criticalOutHigh: $criticalOutHigh
	toDebug unit: $UNIT	

	calculateTraffic
	
	lowIn_w=$(echo "$rateIn < $warningInLow"|bc)
	lowIn_c=$(echo "$rateIn < $criticalInLow"|bc)
	lowOut_w=$(echo "$rateOut < $warningOutLow"|bc)
	lowOut_c=$(echo "$rateOut < $criticalOutLow"|bc)
	highIn_w=$(echo "$rateIn > $warningInHigh"|bc)
	highIn_c=$(echo "$rateIn > $criticalInHigh"|bc)
	highOut_w=$(echo "$rateOut > $warningOutHigh"|bc)
	highOut_c=$(echo "$rateOut > $criticalOutHigh"|bc)
	
	if [ $lowIn_c -eq 1 ];then
		echo "CRITICAL: ${serverIp}_${ifName}_traffic_IN is $rateIn $UNIT, It went below than defined value: $criticalInLow $UNIT, CheckInterval=${diffTime}s."
		Stat_c="true"
	fi
	if [ $lowOut_c -eq 1 ];then
		echo "CRITICAL: ${serverIp}_${ifName}_traffic_OUT is $rateOut $UNIT, It went below than defined value: $criticalOutLow $UNIT, CheckInterval=${diffTime}s."
		Stat_c="true"
	fi
	if [ $highIn_c -eq 1 ];then
		echo "CRITICAL: ${serverIp}_${ifName}_traffic_IN is $rateIn $UNIT, It went above than defined value: $criticalInHigh $UNIT, CheckInterval=${diffTime}s."
		Stat_c="true"
	fi
	if [ $highOut_c -eq 1 ];then
		echo "CRITICAL: ${serverIp}_${ifName}_traffic_OUT is $rateOut $UNIT, It went above than defined value: $criticalOutHigh $UNIT, CheckInterval=${diffTime}s."
		Stat_c="true"
	fi
	if [ $Stat_c = "true" ];then
		exit $CRITICAL
	fi
	
	

	if [ $lowIn_w -eq 1 ];then
		echo "WARNING: ${serverIp}_${ifName}_traffic_IN is $rateIn $UNIT, It went below than defined value: $warningInLow $UNIT, CheckInterval=${diffTime}s."
		Stat_w="true"
	fi
	if [ $lowOut_w -eq 1 ];then
		echo "WARNING: ${serverIp}_${ifName}_traffic_OUT is $rateOut $UNIT, It went below than defined value: $warningOutLow $UNIT, CheckInterval=${diffTime}s."
		Stat_w="true"
	fi
	if [ $highIn_w -eq 1 ];then
		echo "WARNING: ${serverIp}_${ifName}_traffic_IN is $rateIn $UNIT, It went above than defined value: $warningInHigh $UNIT, CheckInterval=${diffTime}s."
		Stat_w="true"
	fi
	if [ $highOut_w -eq 1 ];then
		echo "WARNING: ${serverIp}_${ifName}_traffic_OUT is $rateOut $UNIT, It went above than defined value: $warningOutHigh $UNIT, CheckInterval=${diffTime}s."
		Stat_w="true"
	fi
	if [ $Stat_w = "true" ];then
		exit $WARNING
	fi
	
	echo "TRAFFIC OK: ${serverIp}_${ifName}_traffic OUT:$rateOut $UNIT, IN:$rateIn $UNIT, CheckInterval=${diffTime}s."
	exit $NORMAL
}

mainFunction

