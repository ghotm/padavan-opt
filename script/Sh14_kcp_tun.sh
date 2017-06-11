#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
nvramshow=`nvram show | grep ss | awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
nvramshow=`nvram show | grep kcptun | awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

[ -z $kcptun_enable ] && kcptun_enable=0 && nvram set kcptun_enable=0

kcptun_s_server=""
kcptun_sport=${kcptun_sport:-"29900"}
kcptun_crypt=${kcptun_crypt:-"none"}
kcptun_lport=${kcptun_lport:-"8388"}
kcptun_sndwnd=${kcptun_sndwnd:-"1024"}
kcptun_rcvwnd=${kcptun_rcvwnd:-"1024"}
kcptun_mode=${kcptun_mode:-"fast"}
kcptun_mtu=${kcptun_mtu:-"1350"}
kcptun_dscp=${kcptun_dscp:-"0"}
kcptun_datashard=${kcptun_datashard:-"10"}
kcptun_parityshard=${kcptun_parityshard:-"3"}
kcptun_autoexpire=${kcptun_autoexpire:-"0"}
kcptun_path=${kcptun_path:-"/opt/bin/client_linux_mips"}

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep kcp_tun)" ] ; then
	mkdir -p /tmp/script
	ln -sf $scriptfilepath /tmp/script/_kcp_tun
	chmod 777 /tmp/script/_kcp_tun
fi

kcptun_check () {
A_restart=`nvram get kcptun_status`
B_restart="$kcptun_enable$kcptun_user$kcptun_path$kcptun_parityshard$kcptun_datashard$kcptun_server$kcptun_sport$kcptun_key$kcptun_crypt$kcptun_lport$kcptun_sndwnd$kcptun_rcvwnd$kcptun_mode$kcptun_mtu$kcptun_dscp$(cat /etc/storage/kcptun_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set kcptun_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
if [ "$kcptun_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps - w | grep "$kcptun_path" | grep -v grep )" ] && logger -t "【kcptun】" "停止 $kcptun_path"
	kcptun_close
	{ eval $(ps - w | grep "$scriptname" | grep -v grep | awk '{print "kill "$1;}'); exit 0; }
fi
if [ "$kcptun_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		kcptun_close
		kcptun_start
	else
		[ -z "$(ps - w | grep "$kcptun_path" | grep -v grep )" ] || [ ! -s "$kcptun_path" ] && nvram set kcptun_status=00 && { eval "$scriptfilepath start &"; exit 0; }
	fi
fi

}

kcptun_keep () {
logger -t "【kcptun】" "守护进程启动"
KCPNUM=$(echo `cat /etc/storage/kcptun_script.sh | grep -v "^#" | grep "KCPNUM=" | sed 's/KCPNUM=//'`)
while true; do
	NUM=`ps - w | grep "$kcptun_path" | grep -v grep |wc -l`
	if [ "$NUM" -lt "$KCPNUM" ] || [ "$NUM" -gt "$KCPNUM" ] || [ ! -s "$kcptun_path" ] ; then
		logger -t "【kcptun】" "重新启动$NUM"
		{ eval "$scriptfilepath &" ; exit 0; }
	fi
sleep 214
done
}

kcptun_close () {

[ ! -z "$kcptun_path" ] && eval $(ps - w | grep "$kcptun_path" | grep -v grep | awk '{print "kill "$1}')
killall client_linux_mips kcptun_script.sh sh_kcpkeep.sh
killall -9 client_linux_mips kcptun_script.sh sh_kcpkeep.sh
eval $(ps - w | grep "$scriptname keep" | grep -v grep | awk '{print "kill "$1;}')
}

kcptun_start () {

SVC_PATH="$kcptun_path"
if [ ! -s "$SVC_PATH" ] ; then
	SVC_PATH="/opt/bin/client_linux_mips"
fi
hash client_linux_mips 2>/dev/null || rm -rf /opt/bin/client_linux_mips
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【kcptun】" "找不到 $kcptun_path，安装 opt 程序"
	/tmp/script/_mountopt start
	initopt
fi
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【kcptun】" "找不到 $SVC_PATH 下载程序"
	wgetcurl.sh /opt/bin/client_linux_mips "$hiboyfile/client_linux_mips"
	chmod 755 "/opt/bin/client_linux_mips"
else
	logger -t "【kcptun】" "找到 $SVC_PATH"
fi
if [ ! -s "$SVC_PATH" ] ; then
	logger -t "【kcptun】" "找不到 $SVC_PATH ，需要手动安装 $SVC_PATH"
	logger -t "【kcptun】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && { nvram set kcptun_status=00; eval "$scriptfilepath &"; exit 0; }
fi
if [ -s "$SVC_PATH" ] ; then
	nvram set kcptun_path="$SVC_PATH"
fi
kcptun_path="$SVC_PATH"
kcptun_v=`$SVC_PATH -v | awk '{print $3}'`
nvram set kcptun_v=$kcptun_v
logger -t "【kcptun】" "kcptun-version: $kcptun_v"
logger -t "【kcptun】" "运行 kcptun_script"

resolveip=`/usr/bin/resolveip -4 -t 4 $kcptun_server | grep -v : | sed -n '1p'`
[ -z "$resolveip" ] && resolveip=`nslookup $kcptun_server | awk 'NR==5{print $3}'` 
kcptun_s_server=$resolveip
[ -z "$kcptun_s_server" ] && { logger -t "【kcptun】" "[错误!!] 实在找不到你的 kcptun 服务器IP，麻烦看看哪里错了？10 秒后自动尝试重新启动" && sleep 10 && nvram set kcptun_status=00; eval "$scriptfilepath &"; exit 0; }

sed -Ei '/UI设置自动生成/d' /etc/storage/kcptun_script.sh
sed -Ei '/^$/d' /etc/storage/kcptun_script.sh


# 自动生成客户端启动命令

cat >> "/etc/storage/kcptun_script.sh" <<-EUI
# UI设置自动生成  客户端启动参数
$SVC_PATH $kcptun_user -r "$kcptun_s_server:$kcptun_sport" -l ":$kcptun_lport" -key $kcptun_key -mtu $kcptun_mtu -sndwnd $kcptun_sndwnd -rcvwnd $kcptun_rcvwnd -crypt $kcptun_crypt -mode $kcptun_mode -dscp $kcptun_dscp -datashard $kcptun_datashard -parityshard $kcptun_parityshard -autoexpire $kcptun_autoexpire -nocomp & #UI设置自动生成
# UI设置自动生成  默认启用 -nocomp 参数,需在服务端使用此参数来禁止压缩传输
EUI

# 自动生成服务端启动命令

cat >> "/etc/storage/kcptun_script.sh" <<-EUI
# UI设置自动生成 64位系统 服务端启动参数：此参数复制到服务器启动。（服务端请自行下载部署）
#./server_linux_amd64 -t "$kcptun_s_server:$kcptun_lport" -l ":$kcptun_sport" -key $kcptun_key -mtu $kcptun_mtu -sndwnd 2048 -rcvwnd 2048 -crypt $kcptun_crypt -mode $kcptun_mode -dscp $kcptun_dscp -datashard $kcptun_datashard -parityshard $kcptun_parityshard -nocomp & #UI设置自动生成
# UI设置自动生成 32位系统 服务端启动参数：此参数复制到服务器启动。（服务端请自行下载部署）
#./server_linux_386 -t "$kcptun_s_server:$kcptun_lport" -l ":$kcptun_sport" -key $kcptun_key -mtu $kcptun_mtu -sndwnd 2048 -rcvwnd 2048 -crypt $kcptun_crypt -mode $kcptun_mode -dscp $kcptun_dscp -datashard $kcptun_datashard -parityshard $kcptun_parityshard -nocomp & #UI设置自动生成
EUI

/etc/storage/kcptun_script.sh &
restart_dhcpd
B_restart="$kcptun_enable$kcptun_user$kcptun_path$kcptun_parityshard$kcptun_datashard$kcptun_server$kcptun_sport$kcptun_key$kcptun_crypt$kcptun_lport$kcptun_sndwnd$kcptun_rcvwnd$kcptun_mode$kcptun_mtu$kcptun_dscp$(cat /etc/storage/kcptun_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
[ "$A_restart" != "$B_restart" ] && nvram set kcptun_status=$B_restart
sleep 2
[ ! -z "$(ps - w | grep "$kcptun_path" | grep -v grep )" ] && logger -t "【kcptun】" "启动成功"
[ -z "$(ps - w | grep "$kcptun_path" | grep -v grep )" ] && logger -t "【kcptun】" "启动失败, 注意检查端口是否有冲突,程序是否下载完整,10 秒后自动尝试重新启动" && sleep 10 && { nvram set kcptun_status=00; eval "$scriptfilepath &"; exit 0; }


eval "$scriptfilepath keep &"
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ -s "/opt/etc/init.d/rc.func" ] ; then
	ln -sf "$scriptfilepath" "/opt/etc/init.d/$scriptname"
fi

}

case $ACTION in
start)
	kcptun_close
	kcptun_check
	;;
check)
	kcptun_check
	;;
stop)
	kcptun_close
	;;
keep)
	kcptun_check
	kcptun_keep
	;;
updatekcptun)
	[ "$kcptun_enable" = "1" ] && nvram set kcptun_status="updatekcptun" && logger -t "【kcptun】" "重启" && { eval "$scriptfilepath start &"; exit 0; }
	[ "$kcptun_enable" != "1" ] && [ -f "$kcptun_path" ] && nvram set kcptun_v="" && logger -t "【kcptun】" "更新" && rm -rf $kcptun_path
	;;
*)
	kcptun_check
	;;
esac

