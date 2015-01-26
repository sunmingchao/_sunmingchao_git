#!/bin/sh
#2015-01-24 20:50:24
hour=`date +%H`
user=`/usr/bin/whoami`
from_ip_a=${SSH_CLIENT%% *}
from_ip=${from_ip_a/::ffff:/}
from_user=alert@yoka.com
admin="sunmch126@126.com,azhu1123@qq.com"	#split by comma
config_file=`dirname $0`/usermng.conf
now_h=`date +%Y%m%d%H`
echo " = Now: $now_h "
ctime=`date +%F_%T`

all_ip=`/sbin/ifconfig -a|grep -Eo "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"|grep -Ev "255|127.0.0.1"`
inner_ip=`/sbin/ifconfig  -a|grep -Eo "[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}"|grep -Ev "255|127.0.0.1"|grep -E "10\.0|101\.251"|grep -v "192.191"|head -1`
if [ -z "$inner_ip" ];then
	to_ip=`echo $all_ip|awk '{print $1}'`
else
	to_ip=$inner_ip
fi

if [ $# -eq 0 ];then

	if [ -z "$from_ip" -o  -z "$user" ]; then
		echo "it is me"
		exit
	fi
	if [ "$hour" -ge 22 -o "$hour" -le 7 ];then
		echo "user=${user}, from_ip=${from_ip}, to_ip=${to_ip}, time=$ctime" |mail -s "login_dev186[nighttime]"  -r $from_user $admin
	else
		echo "user=${user}, from_ip=${from_ip}, to_ip=${to_ip}, time=$ctime" |mail -s "login_dev186" -r $from_user $admin
	fi
fi

if [ $# -eq 1 -a "$1" = "sudo" ];then
	userlist=`cat /etc/passwd |grep -E "/bin/zsh|/bin/bash"|awk -F ":" '{print $1}'`" "
	if [ ! -f $config_file ];then
		for user in $userlist;do
			if [ "$user" = "root" -o "$user" = "sunmingchao" -o "$user" = "zhuliang" ];then
				echo "$user -1" >> $config_file
			else
				echo "$user 0" >> $config_file
			fi
		done
	else
		cat $config_file|while read sudoinfo;do
			us=`echo $sudoinfo|awk '{print $1}'`
			id $us >/dev/null 2>&1
			if [ $? -ne 0 ];then
				sed -i '/^'"$us"' /d' $config_file
			fi
			
			for user in $userlist;do
				cat $config_file|egrep -q "^$user "
				if [ $? -ne 0 ];then
					echo "$user 0" >> $config_file
				fi
			done
			
		done
	fi

	sudotag="usermng.sudo.tag"
	cat $config_file|while read sudoinfo;do
		us=`echo $sudoinfo|awk '{print $1}'`
		sd=`echo $sudoinfo|awk '{print $2}'`
		
		if [ "$sd" -lt "$now_h" ];then
			[[ "$sd" -eq "-1" ]] && continue
			grep -q $us.$sudotag /etc/sudoers
			if [ $? -eq 0 ];then
				echo " - del sudoer $us."
				sed -i '/'"$us.$sudotag"'/d' /etc/sudoers
				#echo "delete sudoer $us."|mail -s "sudoer $us delete" -r $from_user $admin && echo "mailing..."
				cat $config_file|mail -s "sudoer $us delete" -r $from_user $admin && echo "mailing..."
			fi
		else	
			grep -q $us.$sudotag /etc/sudoers
			if [ $? -ne 0 ];then
				echo " - add sudoer $us."
				grep -q "$us.$sudotag" /etc/sudoers || echo "$us ALL=(ALL) ALL #$us.$sudotag" >> /etc/sudoers
				#echo "add sudoer $us."|mail -s "sudoer $us added" -r $from_user $admin && echo "mailing..."
			 	cat $config_file|mail -s "sudoer $us added" -r $from_user $admin && echo "mailing..."
			fi
		fi
		
	done
	cat $config_file
fi

