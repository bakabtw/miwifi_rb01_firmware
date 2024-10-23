#!/bin/sh
# Copyright (C) 2014 Xiaomi

#
# $1 = opt. open/close
# usage:
#      ap_mode.sh open/close
#
bridgeap_connect_init() { return 0; }
bridgeap_connect_deinit() { return 0; }

. /lib/functions.sh
. /lib/network/network_func_lib.sh

usage() {
    echo "usage:"
    echo "    ap_mode.sh opt=open/close/check_gw"
    echo "    example1:  ap_mode.sh open"
    echo "    example2:  ap_mode.sh close"
    echo "    example2:  ap_mode.sh check_gw"
}

#$1 : log message
bridgeap_logger()
{
    logger -t bridgeap "$1"
}

#return value 1: gw ip unreachable;
#return value 0: gw ip exists
bridgeap_check_gw()
{
    local bridgeap_gw_ip=`uci get network.lan.gateway`

    bridgeap_logger "current gateway ip $bridgeap_gw_ip"
    [ -z $bridgeap_gw_ip ] && return 0;

    bridgeap_gw_ip_noexist=`arping $bridgeap_gw_ip -I br-lan -c 3 &>/dev/null; echo $?`;
    bridgeap_logger "current gateway ip $bridgeap_gw_ip exist $bridgeap_gw_ip_noexist(1:gw ip unreachable)."
    return $bridgeap_gw_ip_noexist;
}

# return value 1: not ap mode
# return value 0: ap mode;
bridgeap_check_apmode()
{
    local network_apmode=`uci get xiaoqiang.common.NETMODE`

    bridgeap_logger "network apmode $network_apmode."
    [ "$network_apmode" == "lanapmode" ] && return 0;
    
    bridgeap_logger "network apmode $network_apmode false."
    return 1;
}

bridgeap_lan_restart()
{
    bridgeap_logger "try restart lan."
    for i in `seq 1 10`
    do
       /usr/sbin/dhcp_apclient.sh restart
       [ $? = '0' ] && return 0; 

       bridgeap_logger "restart lan fail, try again in $i seconds."
       sleep $i
    done
    
    return 1;
}

# add timer task to crontab
# eg.
# bridgeap mode gateway check
# */1 * * * * /usr/sbin/ap_mode.sh check_gw
bridgeap_check_gw_stop()
{
   grep -v "/usr/sbin/ap_mode.sh check_gw" /etc/crontabs/root > /etc/crontabs/root.new;
   mv /etc/crontabs/root.new /etc/crontabs/root
   /etc/init.d/cron restart 	
}

bridgeap_check_gw_start()
{
   grep -v "/usr/sbin/ap_mode.sh check_gw" /etc/crontabs/root > /etc/crontabs/root.new; 
   echo "*/1 * * * * /usr/sbin/ap_mode.sh check_gw" >> /etc/crontabs/root.new
   mv /etc/crontabs/root.new /etc/crontabs/root
   /etc/init.d/cron restart
}

bridgeap_plugin_restart()
{
  plugin_script="/etc/init.d/plugin_start_script.sh"

  #r1cl doesn't have plugin service.
  [ -f $plugin_script ] || return

  $plugin_script stop
  $plugin_script start
  
  return;
}




wan_start()
{
    has_wan=$(ifconfig $wan_device 1>/dev/null 2>/dev/null; echo $?)
    [ "$has_wan" == "1" ] && return

    ifup wan

    return $?
}

OPT=$1


if [ $# -ne 1 ];
then
    usage
    exit 1
fi

case $OPT in 
    connect)
        wan_start

        # untag wan port then we can send dhcp discovery without vlan tag
        bridgeap_connect_init
        ret=$(/usr/sbin/dhcp_apclient.sh start $wan_device)
        bridgeap_connect_deinit
        return ret
    ;;

    open)
        ifdown vpn
        echo $wan_device $lan_device

        bridgeap_open;
        /etc/init.d/ipv6 ip6_fw close
        /etc/init.d/firewall restart
        /etc/init.d/odhcpd stop
        /etc/init.d/dnsmasq stop
        /usr/sbin/dhcp_apclient.sh restart
        /etc/init.d/network restart
		/etc/init.d/wan_check restart
        /etc/init.d/dnsmasq start
        /usr/sbin/vasinfo_fw.sh off
        /etc/init.d/trafficd restart
        /etc/init.d/xqbc restart
        /etc/init.d/tbusd restart
        /etc/init.d/xiaoqiang_sync start
        [ -f /etc/init.d/hwnat ] && /etc/init.d/hwnat off

        bridgeap_check_gw_start

        bridgeap_plugin_restart
        [ -f /etc/init.d/minet ] && /etc/init.d/minet restart
        [ -f /etc/init.d/cab_meshd ] && /etc/init.d/cab_meshd restart

        return $?
    ;;

    close)
        bridgeap_check_gw_stop
        bridgeap_close;
        /etc/init.d/ipv6 ip6_fw open
        /etc/init.d/firewall restart
        /etc/init.d/odhcpd start
        /etc/init.d/dnsmasq stop
        /etc/init.d/network restart
        /usr/sbin/dhcp_apclient.sh restart
        /etc/init.d/wan_check restart
        /etc/init.d/dnsmasq restart
        /usr/sbin/vasinfo_fw.sh post_ota
        /etc/init.d/trafficd restart
        /etc/init.d/xqbc restart
        /etc/init.d/xiaoqiang_sync stop
        /etc/init.d/tbusd start
        [ -f /etc/init.d/minet ] && /etc/init.d/minet restart
        [ -f /etc/init.d/cab_meshd ] && /etc/init.d/cab_meshd restart
        [ -f /etc/init.d/hwnat ] && /etc/init.d/hwnat start

        bridgeap_plugin_restart
        return $?
    ;;

    check_gw)
        # this part is used for "link up/down" "root ap change" check, in those situation
        # gateway/lan/sta ip must be "dhcp renew"
        bridgeap_logger "check apmode."
        bridgeap_check_apmode
        [ $? = '1' ] && exit 0;

        bridgeap_logger "check gateway."
        bridgeap_check_gw
        [ $? = '0' ] && exit 0;

        # in bridge ap mode and gateway unreachable, we had to run dhcp renew issue;
        # if can't renew ipaddr, script should  exit. otherwise, restart network && lan
        bridgeap_logger "gateway changed, try dhcp renew."
        lan_ipaddr_ori=`uci get network.lan.ipaddr 2>/dev/null`

        /usr/sbin/dhcp_apclient.sh start br-lan;
        lan_ipaddr_now=`uci get network.lan.ipaddr 2>/dev/null`
        [ "$lan_ipaddr_ori" = "$lan_ipaddr_now" ] && exit 0;
        matool --method setKV --params "ap_lan_ip" "$lan_ipaddr_now"

        bridgeap_logger "gateway changed, try lan restart"
        bridgeap_lan_restart
        bridgeap_logger "gateway changed, lan ip changed from $lan_ipaddr_ori to $lan_ipaddr_now."
        /etc/init.d/network restart
        exit 0;
     ;;

     * ) 
        echo "usage:" >&2
  ;;
esac
