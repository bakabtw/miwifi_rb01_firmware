#!/bin/sh
# Copyright (C) 2020 Xiaomi

. /lib/mimesh/mimesh_public.sh
. /lib/mimesh/mimesh_stat.sh
. /lib/mimesh/mimesh_init.sh

log() {
	logger -t "meshd connect: " -p9 "$1"
}

check_re_initted() {
	initted=`uci -q get xiaoqiang.common.INITTED`
	[ "$initted" == "YES" ] && { log "RE already initted. exit 0." ; exit 0; }
}

run_with_lock() {
	{
		log "$$, ====== TRY locking......"
		flock -x -w 60 1000
		[ $? -eq "1" ] && { log "$$, ===== GET lock failed. exit 1" ; exit 1 ; }
		log "$$, ====== GET lock to RUN."
		$@
		log "$$, ====== END lock to RUN."
	} 1000<>/var/log/mesh_connect_lock.lock
}

usage() {
	echo "$0 re_start xx:xx:xx:xx:xx:xx"
	echo "$0 help"
	exit 1
}

eth_down() {
	local ifnames=$(uci -q get network.lan.ifname)
	local wan_ifname=$(uci -q get network.wan.ifname)
	for if_name in $ifnames
	do
		ifconfig $if_name down
	done

	[ -n "$wan_ifname" ] && {
		ifconfig $wan_ifname down
	}
}

eth_up() {
	local ifnames=$(uci -q get network.lan.ifname)
	local wan_ifname=$(uci -q get network.wan.ifname)

	for if_name in $ifnames
	do
		ifconfig $if_name up
	done

	[ -n "$wan_ifname" ] && {
		ifconfig $wan_ifname up
	}
}

set_network_id() {
	local bh_ssid=$1
	local pre_id=$(uci -q get xiaoqiang.common.NETWORK_ID)
	local new_id=$(echo "$bh_ssid" | md5sum | cut -c 1-8)
	if [ -z "$pre_id" -o "$pre_id" != "$new_id" ]; then
		uci set xiaoqiang.common.NETWORK_ID="$new_id"
		uci commit xiaoqiang
	fi
}

# not used by others
cap_close_wps() {
	local ifname=$(uci -q get misc.wireless.ifname_5G)

	iwpriv $ifname set WscStop=1
	iwpriv $ifname set miwifi_mesh=3
}

cap_disable_wps_trigger() {
	local ifname=$1

	iwpriv $ifname set miwifi_mesh=3
}

re_clean_vap() {
	local ifname=$(uci -q get misc.wireless.apclient_5G)

	local lanip=$(uci -q get network.lan.ipaddr)
	if [ "$lanip" != "" ]; then
		ifconfig br-lan $lanip
	else
		ifconfig br-lan 192.168.31.1
	fi

	eth_up
	wifi
}

mimesh_mtk_ping_capip()
{
	local cap_ip=$(uci -q get xiaoqiang.common.CAP_IP)

	if [ -n "$cap_ip" ]; then
		ping $cap_ip -c 1 -w 2 > /dev/null 2>&1
		[ $? -eq 0 ] && return 0
	else
		MIMESH_LOGI "  NO find valid cap ip!"
	fi

	return 1
}

# check RE assoc CAP status
# return 0: associated
# return else: not associated
mimesh_mtk_re_assoc_check()
{
	local iface_5g_bh=$(uci -q get misc.backhauls.backhaul_5g_sta_iface)
	[ -z "$iface_5g_bh" ] && iface_5g_bh="apclii0"

	local conn_status=$(iwpriv "$iface_5g_bh" Connstatus|grep Connected > /dev/null;echo $?)
	[ $conn_status -eq 0 ] && return 0

	mimesh_gateway_ping
	[ $? -eq 0 ] && return 0

	local gw_ip=$(uci -q get network.lan.gateway)
	local cap_ip=$(uci -q get xiaoqiang.common.CAP_IP)
	[ "$gw_ip"x != "$cap_ip"x ] && {
		mimesh_mtk_ping_capip
		return $?
	}

	return 1
}

check_re_init_status_v2() {
	for i in $(seq 1 60)
	do
		mimesh_mtk_re_assoc_check > /dev/null 2>&1
		[ $? = 0 ] && break
		sleep 2
	done

	mimesh_init_done "re"
	/etc/init.d/meshd stop
	eth_up
}

do_re_init() {
	local ifname=$(uci -q get misc.wireless.apclient_5G)
	local device=$(uci -q get misc.wireless.if_5G)

	local ssid_2g="$1"
	local pswd_2g=
	local mgmt_2g=$3

	[ "$mgmt_2g" = "none" ] || pswd_2g="$2"

	local ssid_5g="$4"
	local pswd_5g=
	local mgmt_5g=$6

	[ "$mgmt_5g" = "none" ] || pswd_5g="$5"
	local bh_ssid=$(printf "%s" "$7" | base64 -d)
	local bh_pswd=$(printf "%s" "$8" | base64 -d)
	local bh_mgmt=$9

	set_network_id "$bh_ssid"

	touch /tmp/bh_maclist_5g
	local bh_maclist_5g=$(cat /tmp/bh_maclist_5g | sed 's/ /,/g')
	local bh_macnum_5g=$(echo $bh_maclist_5g | awk -F"," '{print NF}')

	do_re_init_json

	local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"RE\",\"bsd\":\"0\",\"ssid_2g\":\"${ssid_2g}\",\"pswd_2g\":\"${pswd_2g}\",\"mgmt_2g\":\"${mgmt_2g}\",\"ssid_5g\":\"${ssid_5g}\",\"pswd_5g\":\"${pswd_5g}\",\"mgmt_5g\":\"${mgmt_5g}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"${bh_mgmt}\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\"}}"

	mimesh_init "$buff" "$10"

	sleep 2

	check_re_init_status_v2
}

do_re_init_bsd() {
	local ifname=$(uci -q get misc.wireless.apclient_5G)
	local device=$(uci -q get misc.wireless.if_5G)

	local whc_ssid="$1"
	local whc_pswd=
	local whc_mgmt=$3

	[ "$whc_mgmt" = "none" ] || whc_pswd="$2"

	local bh_ssid=$(printf "%s" "$4" | base64 -d)
	local bh_pswd=$(printf "%s" "$5" | base64 -d)
	local bh_mgmt=$6

	set_network_id "$bh_ssid"

	touch /tmp/bh_maclist_5g
	local bh_maclist_5g=$(cat /tmp/bh_maclist_5g | sed 's/ /,/g')
	local bh_macnum_5g=$(echo $bh_maclist_5g | awk -F"," '{print NF}')

	do_re_init_json

	local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"RE\",\"whc_ssid\":\"${whc_ssid}\",\"whc_pswd\":\"${whc_pswd}\",\"whc_mgmt\":\"${whc_mgmt}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"${bh_mgmt}\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\"}}"

	mimesh_init "$buff" "$7"

	sleep 2

	check_re_init_status_v2
}

do_re_init_json() {
	local jsonbuf=$(cat /tmp/extra_wifi_param 2>/dev/null)
	[ -z "$jsonbuf" ] && return

	#set max mesh version we can support
	local version_list=$(uci -q get misc.mesh.version)
	if [ -z "$version_list" ]; then
		log "version list is empty"
		return
	fi

	local max_version=1
	for version in $version_list; do
		if [ $version -gt $max_version ]; then
			max_version=$version
		fi
	done

	uci set xiaoqiang.common.MESH_VERSION="$max_version"
	uci commit

	local device_2g=$(uci -q get misc.wireless.if_2G)
	local device_5g=$(uci -q get misc.wireless.if_5G)
	local ifname_2g=$(uci -q get misc.wireless.ifname_2G)
	local ifname_5g=$(uci -q get misc.wireless.ifname_5G)

	local hidden_2g=$(json_get_value "$jsonbuf" "hidden_2g")
	local hidden_5g=$(json_get_value "$jsonbuf" "hidden_5g")
	local disabled_2g=$(json_get_value "$jsonbuf" "disabled_2g")
	local disabled_5g=$(json_get_value "$jsonbuf" "disabled_5g")
	local ax_2g=$(json_get_value "$jsonbuf" "ax_2g")
	local ax_5g=$(json_get_value "$jsonbuf" "ax_5g")
	local txpwr_2g=$(json_get_value "$jsonbuf" "txpwr_2g")
	local txpwr_5g=$(json_get_value "$jsonbuf" "txpwr_5g")
	local bw_2g=$(json_get_value "$jsonbuf" "bw_2g")
	local bw_5g=$(json_get_value "$jsonbuf" "bw_5g")
	local txbf_2g=$(json_get_value "$jsonbuf" "txbf_2g")
	local txbf_5g=$(json_get_value "$jsonbuf" "txbf_5g")
	local ch_2g=$(json_get_value "$jsonbuf" "ch_2g")
	local ch_5g=$(json_get_value "$jsonbuf" "ch_5g")
	local web_passwd=$(json_get_value "$jsonbuf" "web_passwd")

	[ "$ch_5g" != "auto" -a "$ch_5g" -gt 48 ] && ch_5g="auto"
	uci set wireless.$device_5g.channel="$ch_5g"
	uci set wireless.$device_2g.channel="$ch_2g"

	uci set wireless.$device_5g.ax="$ax_5g"
	uci set wireless.$device_2g.ax="$ax_2g"

	uci set wireless.$device_5g.txpwr="$txpwr_5g"
	uci set wireless.$device_2g.txpwr="$txpwr_2g"

	uci set wireless.$device_5g.txbf="$txbf_5g"
	uci set wireless.$device_2g.txbf="$txbf_2g"

	uci set wireless.$device_2g.bw="$bw_2g"

	local support160_cur=$(uci -q get misc.features.support160Mhz)
	if [ "$support160_cur"x == "0"x -a "$bw_5g" == "160" ]; then
		uci set wireless.$device_5g.bw="80"
	else
		uci set wireless.$device_5g.bw="$bw_5g"
	fi

	local iface_2g=$(uci show wireless | grep -w "ifname='$ifname_2g'" | awk -F"." '{print $2}')
	local iface_5g=$(uci show wireless | grep -w "ifname='$ifname_5g'" | awk -F"." '{print $2}')

	uci set wireless.$iface_2g.hidden="$hidden_2g"
	uci set wireless.$iface_5g.hidden="$hidden_5g"
	
	uci set wireless.$iface_2g.disabled="0"
	uci set wireless.$iface_5g.disabled="0"

	if [ -n "$web_passwd" ]; then
		uci set account.common.admin="$web_passwd"
		uci commit account
	fi

	uci commit wireless

	#cap_mode
	local cap_mode=$(json_get_value "$jsonbuf" "cap_mode")
	uci set xiaoqiang.common.CAP_MODE="$cap_mode"

	local cap_ip=$(json_get_value "$jsonbuf" "cap_ip")
	[ -n "$cap_ip" ] && uci -q set xiaoqiang.common.CAP_IP="$cap_ip"

	if [ "$cap_mode" = "ap" ]; then
		local vendorinfo=$(json_get_value "$jsonbuf" "vendorinfo")
		uci set xiaoqiang.common.vendorinfo="$vendorinfo"
	fi
	uci commit xiaoqiang

	local tz_index=$(json_get_value "$jsonbuf" "tz_index")
	local timezone=$(json_get_value "$jsonbuf" "timezone")
	local lang=$(json_get_value "$jsonbuf" "lang")
	local CountryCode=$(json_get_value "$jsonbuf" "CountryCode")

	if [ -n "$timezone" ]; then
		uci set system.@system[0].timezone=$timezone
		[ -n "$tz_index" ] && uci set system.@system[0].timezoneindex=$tz_index
		uci commit system
		/etc/init.d/timezone restart
	fi

	uci set luci.main.lang=$lang
	uci commit luci

	nvram set CountryCode=$CountryCode
	nvram commit

	local server_S=$(json_get_value "$jsonbuf" "server_S")
	local server_APP=$(json_get_value "$jsonbuf" "server_APP")
	local server_API=$(json_get_value "$jsonbuf" "server_API")
	local server_STUN=$(json_get_value "$jsonbuf" "server_STUN")
	local server_BROKER=$(json_get_value "$jsonbuf" "server_BROKER")

	uci set miwifi.server.S=$server_S
	uci set miwifi.server.APP=$server_APP
	uci set miwifi.server.API=$server_API
	uci set miwifi.server.STUN=$server_STUN
	uci set miwifi.server.BROKER=$server_BROKER
	uci commit miwifi
}

init_cap_mode() {
	local ifname_5g=$(uci -q get misc.wireless.ifname_5G)
	local iface_5g=$(uci show wireless | grep -w "ifname='$ifname_5g'" | awk -F"." '{print $2}')
	/etc/init.d/meshd stop
	uci set wireless.$iface_5g.miwifi_mesh=0
	uci commit wireless
}

cap_down_vap() {
	local ifname=$(uci -q get misc.wireless.mesh_ifname_5G)
	brctl delif br-lan $ifname
	ifconfig $ifname down
}

cap_clean_vap() {
	local ifname=$1
	local name=$(echo $2 | sed s/[:]//g)
	cap_down_vap
	echo "failed" > /tmp/${name}-status
}

mimesh_mtk_cap_bh_check()
{
	local iface_5g_bh=$(uci -q get misc.backhauls.backhaul_5g_ap_iface)

	[ -z "$iface_5g_bh" ] && iface_5g_bh="wl5"

	iwpriv $iface_5g_bh get mimesh_backhaul | grep -wq "get:1"

	return $?
}

check_cap_init_status_v2() {
	local ifname=$(uci -q get misc.backhauls.backhaul_5g_ap_iface)
	local device_5g=$(uci -q get misc.wireless.if_5G)
	local re_5g_mac=$2
	local is_cable=$5
	[ -z "$is_cable" ] && is_cable=0

	for i in $(seq 1 60)
	do
		mimesh_mtk_cap_bh_check > /dev/null 2>&1
		if [ $? = 0 ]; then
			mimesh_init_done "cap"
			sleep 2
			init_done=1
			break
		fi
		sleep 2
	done

	if [ $init_done -eq 1 ]; then
		for i in $(seq 1 90)
		do
			local assoc_count1=$(iwinfo $ifname a | grep -i -c $3)
			local assoc_count2=$(iwinfo $ifname a | grep -i -c $4)

			if [ $is_cable == "1" -o $assoc_count1 -gt 0 -o $assoc_count2 -gt 0 ]; then
				/sbin/cap_push_backhaul_whitelist.sh
				/usr/sbin/topomon_action.sh cap_init
				echo "success" > /tmp/$1-status
				exit 0
			fi
			sleep 2
		done
	fi

	echo "failed" > /tmp/$1-status
	exit 1
}

do_cap_init_bsd() {
	local name=$(echo $1 | sed s/[:]//g)
	local is_cable=$8
	[ -z "$is_cable" ] && is_cable=0

	local ifname_ap_2g=$(uci -q get misc.wireless.ifname_2G)
	local iface_2g=$(uci show wireless | grep -w "ifname='$ifname_ap_2g'" | awk -F"." '{print $2}')

	local whc_ssid=$(uci -q get wireless.$iface_2g.ssid)
	local whc_pswd=$(uci -q get wireless.$iface_2g.key)
	local whc_mgmt=$(uci -q get wireless.$iface_2g.encryption)

	local ifname_5g=$(uci -q get misc.backhauls.backhaul_5g_ap_iface)

	local bh_ssid=$(printf "%s" "$6" | base64 -d)
	local bh_pswd=$(printf "%s" "$7" | base64 -d)
	local init_done=0

	local device_5g=$(uci -q get misc.wireless.if_5G)

	local channel=$(uci -q get wireless.$device_5g.channel)
	local bw=$(uci -q get wireless.$device_5g.bw)

	echo "syncd" > /tmp/${name}-status

	set_network_id "$bh_ssid"

	cap_down_vap

	local mode=$(uci -q get xiaoqiang.common.NETMODE)
	local cap_mode=$(uci -q get xiaoqiang.common.CAP_MODE)
	[ "whc_cap" = "$mode" -o "$mode" = "lanapmode" -a "$cap_mode" = "ap" ] || {
		local bh_maclist_5g=
		local bh_macnum_5g=0

		if [ "$whc_mgmt" == "ccmp" ]; then
			whc_pswd=$(uci -q get wireless.$iface_2g.sae_password)
		fi

		whc_ssid=$(printf "%s" "$whc_ssid" | base64 | xargs)
		whc_pswd=$(printf "%s" "$whc_pswd" | base64 | xargs)

		case "$channel" in
			52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165)
				uci set wireless.$device_5g.channel='auto'
				uci commit wireless
				;;
			*) ;;
		esac

		local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"CAP\",\"whc_ssid\":\"${whc_ssid}\",\"whc_pswd\":\"${whc_pswd}\",\"whc_mgmt\":\"${whc_mgmt}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"psk2\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\"}}"
		mimesh_init "$buff"
	}

	check_cap_init_status_v2 $name $1 $3 $5 $is_cable
}

do_cap_init() {
	local name=$(echo $1 | sed s/[:]//g)
	local is_cable=$8
	[ -z "$is_cable" ] && is_cable=0

	local ifname_ap_2g=$(uci -q get misc.wireless.ifname_2G)
	local iface_2g=$(uci show wireless | grep -w "ifname='$ifname_ap_2g'" | awk -F"." '{print $2}')
	local ifname_ap_5g=$(uci -q get misc.wireless.ifname_5G)
	local iface_5g=$(uci show wireless | grep -w "ifname='$ifname_ap_5g'" | awk -F"." '{print $2}')
	local device_5g=$(uci -q get misc.wireless.if_5G)

	local ssid_2g=$(uci -q get wireless.$iface_2g.ssid)
	local pswd_2g=$(uci -q get wireless.$iface_2g.key)
	local mgmt_2g=$(uci -q get wireless.$iface_2g.encryption)
	local ssid_5g=$(uci -q get wireless.$iface_5g.ssid)
	local pswd_5g=$(uci -q get wireless.$iface_5g.key)
	local mgmt_5g=$(uci -q get wireless.$iface_5g.encryption)

	local bh_ifname_5g=$(uci -q get misc.backhauls.backhaul_5g_ap_iface)

	local bh_ssid=$(printf "%s" "$6" | base64 -d)
	local bh_pswd=$(printf "%s" "$7" | base64 -d)
	local init_done=0

	local channel=$(uci -q get wireless.$device_5g.channel)
	local bw=$(uci -q get wireless.$device_5g.bw)

	echo "syncd" > /tmp/${name}-status

	set_network_id "$bh_ssid"

	cap_down_vap

	local mode=$(uci -q get xiaoqiang.common.NETMODE)

	local cap_mode=$(uci -q get xiaoqiang.common.CAP_MODE)
	[ "whc_cap" = "$mode" -o "$mode" = "lanapmode" -a "$cap_mode" = "ap" ] || {
		local bh_maclist_5g=
		local bh_macnum_5g=0

		if [ "$mgmt_2g" == "ccmp" ]; then
			pswd_2g=$(uci -q get wireless.$iface_2g.sae_password)
		fi

		if [ "$mgmt_5g" == "ccmp" ]; then
			pswd_5g=$(uci -q get wireless.$iface_5g.sae_password)
		fi

		ssid_2g=$(printf "%s" "$ssid_2g" | base64 | xargs)
		pswd_2g=$(printf "%s" "$pswd_2g" | base64 | xargs)
		ssid_5g=$(printf "%s" "$ssid_5g" | base64 | xargs)
		pswd_5g=$(printf "%s" "$pswd_5g" | base64 | xargs)

		case "$channel" in
			52|56|60|64|100|104|108|112|116|120|124|128|132|136|140|149|153|157|161|165)
				uci set wireless.$device_5g.channel='auto'
				uci commit wireless
				;;
			*) ;;
		esac

		local buff="{\"method\":\"init\",\"params\":{\"whc_role\":\"CAP\",\"bsd\":\"0\",\"ssid_2g\":\"${ssid_2g}\",\"pswd_2g\":\"${pswd_2g}\",\"mgmt_2g\":\"${mgmt_2g}\",\"ssid_5g\":\"${ssid_5g}\",\"pswd_5g\":\"${pswd_5g}\",\"mgmt_5g\":\"${mgmt_5g}\",\"bh_ssid\":\"${bh_ssid}\",\"bh_pswd\":\"${bh_pswd}\",\"bh_mgmt\":\"psk2\",\"bh_macnum_5g\":\"${bh_macnum_5g}\",\"bh_maclist_5g\":\"${bh_maclist_5g}\",\"bh_macnum_2g\":\"0\",\"bh_maclist_2g\":\"\"}}"

		mimesh_init "$buff"
	}

	check_cap_init_status_v2 $name $1 $3 $5 $is_cable
}

do_re_dhcp() {
	local bridge="br-lan"
	local ifname=$(uci -q get misc.wireless.apclient_5G)
	local model=$(uci -q get misc.hardware.model)
	[ -z "$model" ] && model=$(cat /proc/xiaoqiang/model)

	brctl addif br-lan ${ifname}

	ifconfig br-lan 0.0.0.0

	#udhcpc on br-lan, for re init time optimization
	udhcpc -q -p /var/run/udhcpc-${bridge}.pid -s /usr/share/udhcpc/mesh_dhcp.script -f -t 0 -i $bridge -x hostname:MiWiFi-${model}

	exit $?
}

re_start_wps() {
	local ifname=$(uci -q get misc.wireless.apclient_5G)
	local ifname_5G=$(uci -q get misc.wireless.ifname_5G)
	local device=$(uci -q get misc.wireless.${ifname}_device)
	local macaddr="$1"
	local channel="$2"

	eth_down

	iwpriv $ifname_5G set Channel=$channel
	sleep 2

	ifconfig $ifname up
	iwpriv $ifname set ApCliMWDS=1
	iwpriv $ifname set ApCliEnable=0
	iwpriv $ifname set ApCliWscBssid="$macaddr"
	iwpriv $ifname set WscConfMode=1
	iwpriv $ifname set WscMode=2
	iwpriv $ifname set ApCliEnable=1
	iwpriv $ifname set WscGetConf=1

	for i in $(seq 1 60)
	do
		linkup=$(iwpriv $ifname Connstatus|grep Connected >/dev/null;echo $?)
		if [ $linkup -eq 0 ]; then
			exit 0
		fi

		sleep 2
	done

	eth_up

	iwpriv $ifname set WscConfMode=0
	ifconfig $ifname down

	exit 1
}

cap_start_wps() {
	local ifname=$(uci -q get misc.wireless.mesh_ifname_5G)
	local status_file=$(echo $1 | sed s/[:]//g)
	local ssid_rand=$(openssl rand -base64 8 2>/dev/null | md5sum | cut -c1-16)
	local key=$(openssl rand -base64 8 2>/dev/null| md5sum | cut -c1-32)

	echo "init" > /tmp/${status_file}-status
	ifconfig $ifname up
	sleep 2

	brctl addif br-lan $ifname

	iwpriv $ifname set AuthMode=WPA2PSK
	iwpriv $ifname set EncrypType=AES
	iwpriv $ifname set SSID="wps-$ssid_rand"
	iwpriv $ifname set WPAPSK="$key"
	iwpriv $ifname set SSID="wps-$ssid_rand"
	iwpriv $ifname set ApMWDS=1

	iwpriv $ifname set miwifi_mesh=2
	iwpriv $ifname set miwifi_mesh_mac="$1"

	iwpriv $ifname set ACLClearAll=1
	iwpriv $ifname set AccessPolicy=1 
	iwpriv $ifname set ACLAddEntry="$2"

	iwpriv $ifname set WscConfMode=4;
	iwpriv $ifname set WscMode=2;
	iwpriv $ifname set WscConfStatus=2;
	iwpriv $ifname set WscGetConf=1;

	for i in $(seq 1 60)
	do
		local wps_status=$(iwpriv $ifname get WscStatus|cut -d ':' -f 2|tr '\n' ' ')
		if [ $wps_status -eq 2 ]; then
			echo "connected" > /tmp/${status_file}-status
			cap_disable_wps_trigger $ifname
			exit 0
		fi
		sleep 2
	done

	iwpriv $ifname set WscConfMode=0
	cap_down_vap
	echo "failed" > /tmp/${status_file}-status

	exit 1
}

case "$1" in
	re_start)
	re_start_wps "$2" "$3"
	;;
	cap_start)
	cap_start_wps "$2" "$3"
	;;
	cap_close)
	cap_close_wps
	;;
	init_cap)
	init_cap_mode
	;;
	cap_init)
	run_with_lock do_cap_init "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
	;;
	cap_init_bsd)
	do_cap_init_bsd "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
	;;
	re_init)
	run_with_lock do_re_init "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "$10" "$11"
	;;
	re_init_bsd)
	do_re_init_bsd "$2" "$3" "$4" "$5" "$6" "$7" "$8"
	;;
	re_dhcp)
	do_re_dhcp
	;;
	cap_clean)
	cap_clean_vap "$2" "$3"
	;;
	re_clean)
	re_clean_vap
	;;
	re_init_json)
	do_re_init_json "$2"
	;;
	*)
	usage
	;;
esac
