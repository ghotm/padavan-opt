#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
nvramshow=`nvram show | grep jbls | awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

[ -z $jbls_enable ] && jbls_enable=0 && nvram set jbls_enable=0

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep jbls)" ] ; then
	mkdir -p /tmp/script
	ln -sf $scriptfilepath /tmp/script/_jbls
	chmod 777 /tmp/script/_jbls
fi

jbls_check () {
if [ "$jbls_enable" != "1" ] ; then
	[ ! -z "`pidof jblicsvr`" ] && logger -t "【jbls】" "停止 jblicsvr"
	jbls_close
	{ eval $(ps - w | grep "$scriptname" | grep -v grep | awk '{print "kill "$1;}'); exit 0; }
fi
if [ -z "`pidof jblicsvr`" ] && [ "$jbls_enable" = "1" ] ; then
	jbls_close
	jbls_start
fi

}

jbls_keep () {
logger -t "【jbls】" "守护进程启动"
while true; do
	if [ -z "`pidof jblicsvr`" ] ; then
		logger -t "【jbls】" "重新启动"
		{ eval "$scriptfilepath &" ; exit 0; }
	fi
sleep 993
done
}

jbls_close () {
sed -Ei '/txt-record=_jetbrains-license-server.lan/d' /etc/storage/dnsmasq/dnsmasq.conf
killall jblicsvr jbls_script.sh
killall -9 jblicsvr jbls_script.sh
eval $(ps - w | grep "$scriptname keep" | grep -v grep | awk '{print "kill "$1;}')
}

jbls_start () {
#jblicsvr -d -p 1027
/etc/storage/jbls_script.sh
sleep 2
[ ! -z "$(ps - w | grep "jblicsvr" | grep -v grep )" ] && logger -t "【jbls】" "启动成功"
[ -z "$(ps - w | grep "jblicsvr" | grep -v grep )" ] && logger -t "【jbls】" "启动失败, 注意检查端口是否有冲突,10 秒后自动尝试重新启动" && sleep 10 && { eval "$scriptfilepath &"; exit 0; }
eval "$scriptfilepath keep &"
}


case $ACTION in
start)
	jbls_close
	jbls_check
	;;
check)
	jbls_check
	;;
stop)
	jbls_close
	;;
keep)
	jbls_check
	jbls_keep
	;;
*)
	jbls_check
	;;
esac

