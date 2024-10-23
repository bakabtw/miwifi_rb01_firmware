#!/bin/sh
# Copyright (C) 2014 Xiaomi

#
# $1 = opt. open/close
# usage:
#      re_mode.sh open/close
#

wifiap_open() { return 0; }
wifiap_close() { return 0; }

. /lib/functions.sh
. /lib/network/network_func_lib.sh

usage() {
    echo "usage:"
    echo "    re_mode.sh opt=open/close/check_gw"
    echo "    example1:  re_mode.sh open"
    echo "    example2:  re_mode.sh close"
    echo "    example2:  re_mode.sh check_gw"
}

#$1 : log message
log()
{
    logger -t RE "$1"
    #echo "$1"
}

#return value 1: gw ip unreachable;
#return value 0: gw ip exists
check_gw()
{
    local gw_ip=`uci get network.lan.gateway`

    log "current gateway ip $gw_ip"
    [ -z $gw_ip ] && return 0;

    gw_ip_noexist=`arping $gw_ip -I br-lan -c 3 &>/dev/null; echo $?`;
    log "current gateway ip $gw_ip exist $gw_ip_noexist(1:gw ip unreachable)."
    return $gw_ip_noexist;
}

# return value 1: not ap mode
# return value 0: ap mode;
check_apmode()
{
    local netmode=`uci get xiaoqiang.common.NETMODE`

    log "network apmode $netmode."
    [ "$netmode" == "wifiapmode" ] && return 0;
    
    log "network apmode $netmode false."
    return 1;
}

lan_restart()
{
    log "try restart lan."
    for i in `seq 1 10`
    do
       /usr/sbin/dhcp_apclient.sh restart
       [ $? = '0' ] && return 0; 

       log "restart lan fail, try again in $i seconds."
       sleep $i
    done
    
    return 1;
}

check_gw_stop()
{
   grep -v "/usr/sbin/re_mode.sh check_gw" /etc/crontabs/root > /etc/crontabs/root.new;
   mv /etc/crontabs/root.new /etc/crontabs/root
   /etc/init.d/cron restart 	
}

check_gw_start()
{
   grep -v "/usr/sbin/re_mode.sh check_gw" /etc/crontabs/root > /etc/crontabs/root.new; 
   echo "*/1 * * * * /usr/sbin/re_mode.sh check_gw" >> /etc/crontabs/root.new
   mv /etc/crontabs/root.new /etc/crontabs/root
   /etc/init.d/cron restart
}

OPT=$1

[ $# -ne 1 ] && {
	usage
    exit 1
}

case $OPT in 
    open)

        wifiap_open;
		/usr/sbin/dhcp_apclient.sh restart lan
		/etc/init.d/ipv6 ip6_fw close
		/etc/init.d/firewall restart
		/etc/init.d/odhcpd stop
		/etc/init.d/network restart
		/etc/init.d/wan_check restart
		/etc/init.d/trafficd restart
		/etc/init.d/xiaoqiang_sync start
		/usr/sbin/shareUpdate -b
		/etc/init.d/xqbc restart
		/etc/init.d/miqos stop
		[ -f /etc/init.d/hwnat ] && /etc/init.d/hwnat off
		/etc/init.d/plugin_start_script.sh stop
		/etc/init.d/plugin_start_script.sh start
		[ -f /etc/init.d/minet ] && /etc/init.d/minet restart
		/etc/init.d/tbusd stop
		
		check_gw_start

		[ -f /etc/init.d/cab_meshd ] && /etc/init.d/cab_meshd stop
		
        return $?
    ;;

    close)

		wifiap_close
		/usr/sbin/dhcp_apclient.sh restart lan
		/etc/init.d/ipv6 ip6_fw open
		/etc/init.d/firewall restart
		/etc/init.d/odhcpd start
		/etc/init.d/network restart
		/etc/init.d/wan_check restart
		/etc/init.d/trafficd restart
		/etc/init.d/xiaoqiang_sync stop
		/usr/sbin/shareUpdate -b
		/etc/init.d/dnsmasq enable
		/etc/init.d/dnsmasq restart
		/etc/init.d/xqbc restart
		/etc/init.d/miqos start
		/etc/init.d/tbusd start
		/etc/init.d/plugin_start_script.sh stop
		/etc/init.d/plugin_start_script.sh start
		
		check_gw_stop
		
		[ -f /etc/init.d/hwnat ] && /etc/init.d/hwnat restart
		[ -f /etc/init.d/minet ] && /etc/init.d/minet restart
		[ -f /etc/init.d/cab_meshd ] && /etc/init.d/cab_meshd restart
		
        return $?
    ;;

    check_gw)

        log "check apmode."
        check_apmode
        [ $? = '1' ] && exit 0;

        log "check gateway."
        check_gw
        [ $? = '0' ] && exit 0;

        # in bridge ap mode and gateway unreachable, we had to run dhcp renew issue;
        # if can't renew ipaddr, script should  exit. otherwise, restart network && lan
        log "gateway changed, try dhcp renew."
        lan_ipaddr_ori=`uci get network.lan.ipaddr 2>/dev/null`

        /usr/sbin/dhcp_apclient.sh start br-lan;
        lan_ipaddr_now=`uci get network.lan.ipaddr 2>/dev/null`
        [ "$lan_ipaddr_ori" = "$lan_ipaddr_now" ] && exit 0;
        matool --method setKV --params "ap_lan_ip" "$lan_ipaddr_now"

        log "gateway changed, try lan restart"
        lan_restart
        log "gateway changed, lan ip changed from $lan_ipaddr_ori to $lan_ipaddr_now."
        /etc/init.d/network restart
        exit 0;
     ;;

     * ) 
        echo "usage:" >&2
  ;;
esac
