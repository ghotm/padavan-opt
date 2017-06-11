#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
nvramshow=`nvram show | grep kms | awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

[ -z $kms_enable ] && kms_enable=0 && nvram set kms_enable=0

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep kms)" ] ; then
	mkdir -p /tmp/script
	ln -sf $scriptfilepath /tmp/script/_kms
	chmod 777 /tmp/script/_kms
fi

kms_check () {
if [ "$kms_enable" != "1" ] ; then
	[ ! -z "`pidof vlmcsd`" ] && logger -t "【kms】" "停止 vlmcsd"
	kms_close
	{ eval $(ps - w | grep "$scriptname" | grep -v grep | awk '{print "kill "$1;}'); exit 0; }
fi
if [ -z "`pidof vlmcsd`" ] && [ "$kms_enable" = "1" ] ; then
	kms_close
	kms_start
fi

}

kms_keep () {
logger -t "【kms】" "守护进程启动"
while true; do
	if [ -z "`pidof vlmcsd`" ] ; then
		logger -t "【kms】" "重新启动"
		{ eval "$scriptfilepath &" ; exit 0; }
	fi
sleep 992
done
}

kms_close () {
sed -Ei '/_vlmcs._tcp/d' /etc/storage/dnsmasq/dnsmasq.conf; restart_dhcpd;
killall vlmcsd vlmcsdini_script.sh
killall -9 vlmcsd vlmcsdini_script.sh
eval $(ps - w | grep "$scriptname keep" | grep -v grep | awk '{print "kill "$1;}')
}

kms_start () {
[ ! -f /etc_ro/vlmcsd.kmd ] && /usr/bin/vlmcsd -i /etc/storage/vlmcsdini_script.sh -l /tmp/vlmcsd.log &
[ -f /etc_ro/vlmcsd.kmd ] && /usr/bin/vlmcsd -j /etc_ro/vlmcsd.kmd -i /etc/storage/vlmcsdini_script.sh -l /tmp/vlmcsd.log &
computer_name=`nvram get computer_name`
sed -Ei '/_vlmcs._tcp/d' /etc/storage/dnsmasq/dnsmasq.conf
nvram set lan_domain="lan"
echo "srv-host=_vlmcs._tcp.lan,$computer_name.lan,1688,0,100" >> /etc/storage/dnsmasq/dnsmasq.conf
/etc/storage/vlmcsdini_script.sh
restart_dhcpd
sleep 2
[ ! -z "$(ps - w | grep "vlmcsd" | grep -v grep )" ] && logger -t "【kms】" "启动成功"
[ -z "$(ps - w | grep "vlmcsd" | grep -v grep )" ] && logger -t "【kms】" "启动失败, 注意检查端口是否有冲突,10 秒后自动尝试重新启动" && sleep 10 && { eval "$scriptfilepath &"; exit 0; }
eval "$scriptfilepath keep &"
}


case $ACTION in
start)
	kms_close
	kms_check
	;;
check)
	kms_check
	;;
stop)
	kms_close
	;;
keep)
	kms_check
	kms_keep
	;;
*)
	kms_check
	;;
esac

