#!/bin/sh

logger -t trafficd_notify -p notice "mac:$MAC,type:$TYPE,event:$EVENT,ifname:$IFNAME,is_repeat:$IS_REPEAT,ip:$IP"
#mac:
#	11:22:AA:BB:CC:DD
#type:
#	router
#	ap
#event:
#	0(下线）
#	1(上线）
#	3(ip改变)
#ifname:
#	eth1 eth2 eth3 eth0 wl0 wl1
#is_repeat:
#	0(第一次)
#	1(非第一次)
#ip:
#	192.168.31.1(可能不存在）

ifname_prefix=${IFNAME:0:2}
if [ "x$ifname_prefix" == "xwl" ]; then
	#EVENT 0-offline, 1-online
    if [ "x$EVENT" == "x1" ]; then
        #/sbin/chk_newsta_onre $MAC $IFNAME $EVENT
		new_sta_onre_f="/tmp/new_sta_onre"
		#wps_status 1-wps on
		wps_status="`/sbin/wps status 2>/dev/null`"
		if [ $wps_status -ne 1 ]; then
			rm "$new_sta_onre_f" 2>/dev/null
			return 0
		fi
		[ -n "$MAC" ] && echo "$MAC" > "$new_sta_onre_f"
    fi
fi


