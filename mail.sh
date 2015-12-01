#!/bin/bash

[[ $# -ne 3 ]] && echo "Usag: sh $0 user subject content " && exit
#echo -e "`date` \nTO:\n $1 \n\nSUBJECT:\n $2 \n\nDATA:\n $3 \n=================\n"  >>/usr/local/zabbix-server/zabbix_alert.log

#send email without authentication
#/usr/local/bin/sendEmail -t "$1" -u "$2" -m "$3" -f alert@r.com -o message-charset=utf-8 -o message-content-type=html

/usr/local/bin/sendEmail -s smtp.139.com -xp xxxpasswd -xu sunmch -f ssss@139.com -m "$3" -t "$1" -u "$2" -o message-charset=utf-8 -o message-content-type=html

if [ $? -eq 0 ];then
        echo "Send mail successfully."
else
        echo "Some error occured"
fi
