#!/bin/sh

readonly PPPOE_WAN_ITF="pppoe-wan"
wanip=""
wannetmask="255.255.255.0"
lanip="192.168.31.1"
lannetmask="255.255.255.0"
miotip="192.168.32.1"
miotnetmask="255.255.255.0"
guestip="192.168.33.1"
guestnetmask="255.255.255.0"


usage() {
	echo "usage:"
	echo "ip_conflict.sh newlanip : detect lan/wan ip conflict and save new lanip to /etc/config/network"
	echo "ip_conflict.sh lanwan : just detect lan/wan ip conflict, return false if not conlict, otherwise return newip"
	echo "ip_conflict.sh miot <lanip> <lannetmask> : detect miot/lan ip conflict and save new miotip to /etc/config/network"
	echo "ip_conflict.sh miot <lanip> <lannetmask> chk_wan : detect miot/lan/wan ip conflict and save new miotip to /etc/config/network"
	echo "ip_conflict.sh restart_service: restart some servers which related to lan ip"
}

log() {
	logger -p info -t "ip_conflict.sh" "$1"
}

get_wan_ip_info() {
	local proto=$(uci -q get network.wan.proto)
	local wanitf=$(uci -q get network.wan.ifname)
	[ "$proto" = "pppoe" ] && wanitf=$PPPOE_WAN_ITF
	wanip=$(ifconfig $wanitf | grep "inet addr" | cut -d ':' -f 2 | cut -d ' ' -f 1)
	wannetmask=$(ifconfig $wanitf | grep "Mask" | cut -d ':' -f 4)
}

get_lan_ip_info() {
	lanip=$(uci -q get network.lan.ipaddr)
	lannetmask=$(uci -q get network.lan.netmask)
}

get_miot_ip_info() {
	miotip=$(uci -q get network.miot.ipaddr)
	miotnetmask=$(uci -q get network.miot.netmask)
}

get_guest_ip_info() {
	guestip=$(uci -q get network.guest.ipaddr)
	guestnetmask=$(uci -q get network.guest.netmask)
}

ip_aton() {
	echo $1 | awk '{c=256;split($0,str,".");print str[4]+str[3]*c+str[2]*c^2+str[1]*c^3}'
}

ip_ntoa() {
	local a1=$(($1 & 0xFF))
	local a2=$((($1 >> 8) & 0xFF))
	local a3=$((($1 >> 16) & 0xFF))
	local a4=$((($1 >> 24) & 0xFF))
	echo "$a4.$a3.$a2.$a1"
}

is_same_subnet() {
	local ip1=$1
	local ip2=$2
	local netmask1=$3
	local netmask2=$4

	[ $(($ip1 & $netmask1)) -eq $(($ip2 & $netmask1)) ] && echo 1 && return
	[ $(($ip1 & $netmask2)) -eq $(($ip2 & $netmask2)) ] && echo 1 && return

	echo 0
}

calc_netmask_bits() {
	local bits=0
	local a=$(echo "$1" | awk -F "." '{print $1" "$2" "$3" "$4}')
	for num in $a
	do
		while [ $num != 0 ]
		do
			local re=$(($num % 2))
			[ $re -ne 0 ] && bits=$(($bits + 1))
			num=$(($num / 2))
		done
	done
	echo $bits
}

get_new_ip() {
	local ip=$1
	local netmask1_bits=$(calc_netmask_bits $2)
	local netmask2_bits=$(calc_netmask_bits $3)
	local bits=$4

	[ $netmask1_bits -gt $netmask2_bits ] && netmask1_bits=$netmask2_bits
	[ $netmask1_bits -gt 32 -o $netmask1_bits -lt 8 ] && echo 0 && return
	[ -z "$bits" ] && bits=3

	bits=$(($bits << (32 - $netmask1_bits)))
	echo $(($ip ^ $bits))
}

ip_conflict_detection() {
	#check lan/wan ip
	get_lan_ip_info
	get_wan_ip_info
	[ -z "$lanip" -o -z "$wanip" -o -z "$lannetmask" -o -z "$wannetmask" ] && echo "0.0.0.0" && return

	local lanip_int=$(ip_aton $lanip)
	local wanip_int=$(ip_aton $wanip)
	local lannetmask_int=$(ip_aton $lannetmask)
	local wannetmask_int=$(ip_aton $wannetmask)

	local res=$(is_same_subnet $lanip_int $wanip_int $lannetmask_int $wannetmask_int)
	[ "$res" = "1" ] && {
		local newip_int=$(get_new_ip $lanip_int $lannetmask $wannetmask 3)
		local newip=$(ip_ntoa $newip_int)
		echo $newip && return
	}

	#check miot/wan ip
	get_miot_ip_info
	local miotip_int=$(ip_aton $miotip)
	local miotnetmask_int=$(ip_aton $miotnetmask)
	[ -z "$miotip" -o -z "$miotnetmask" ] && echo "0.0.0.0" && return
	res=$(is_same_subnet $miotip_int $wanip_int $miotnetmask_int $wannetmask_int)
	[ "$res" = "1" ] && {
		local newip_int=$(get_new_ip $miotip_int $miotnetmask $wannetmask 3)
		[ "$newip_int" = "0" ] && {
			log "0 calc newip for miot failed(miotnetmask=$miotnetmask, wannetmask=$wannetmask)!"
			echo "0.0.0.0" && return
		}

		[ $lannetmask_int -lt $miotnetmask_int] && {
			miotnetmask_int=$lannetmask_int
			miotnetmask=$lannetmask
		}
		res=$(is_same_subnet $newip_int $lanip_int $miotnetmask_int $lannetmask_int)
		[ "$res" = "1" ] && {
			newip_int=$(get_new_ip $miotip_int $miotnetmask $lannetmask 7)
			[ "$newip_int" = "0" ] && {
				log "0 calc newip for miot failed(miotnetmask=$miotnetmask, lannetmask=$lannetmask)!"
				echo "0.0.0.0" && return
			}
		}

		local newip=$(ip_ntoa newip_int)
		log "0 change miot ipaddr to $newip"
		uci set network.miot.ipaddr=$newip
		uci commit network
		ubus call network reload
	}

	echo "0.0.0.0"
}

#set new lan ip
ip_conflict_resolution() {
	local newip=$(ip_conflict_detection)
	[ -z "$newip" -o "$newip" = "0.0.0.0" ] && echo "0.0.0.0" && return

	uci set network.lan.ipaddr=$newip
	uci commit network
	log "change lan ipaddr to $newip"

	miot_conflict_resolution

	echo $newip
}

#miot/lan ip
miot_conflict_resolution() {
	lanip=$1
	lannetmask=$2
	[ -z "$lanip" -o -z "$lannetmask" ] && get_lan_ip_info
	get_miot_ip_info
	[ -z "$lanip" -o -z "$lannetmask" -o -z "$miotip" -o -z "$miotnetmask" ] && return

	local lanip_int=$(ip_aton $lanip)
	local lannetmask_int=$(ip_aton $lannetmask)
	local miotip_int=$(ip_aton $miotip)
	local miotnetmask_int=$(ip_aton $miotnetmask)

	local res=$(is_same_subnet $miotip_int $lanip_int $miotnetmask_int $lannetmask_int)
	[ "$res" = "1" ] && {
		local newip_int=$(get_new_ip $miotip_int $miotnetmask $lannetmask 3)
		[ "$newip_int" = "0" ] && {
			log "1 calc newip for miot failed(miotnetmask=$miotnetmask, lannetmask=$lannetmask)!"
			return
		}

		[ "$3" = "chk_wan" ] && {
			get_wan_ip_info
			[ -n "$wanip" -a -n "$wannetmask" ] && {
				[ $lannetmask_int -lt $miotnetmask_int] && {
					miotnetmask_int=$lannetmask_int
					miotnetmask=$lannetmask
				}
				res=$(is_same_subnet $newip_int $wanip_int $miotnetmask_int $wannetmask_int)
				[ "$res" = "1" ] && {
					newip_int=$(get_new_ip $miotip_int $miotnetmask $wannetmask 7)
					[ "$newip_int" = "0" ] && {
						log "1 calc newip for miot failed(miotnetmask=$miotnetmask, wannetmask=$wannetmask)!"
						return
					}
				}
			}
		}

		local newip=$(ip_ntoa newip_int)
		uci set network.miot.ipaddr=$newip
		uci commit network
		log "1 change miot ipaddr to $newip"
	}
}

guest_conflict_resolution() {
	local guest_exist=1
	lanip=$1
	lannetmask=$2
	[ -z "$lanip" -o -z "$lannetmask" ] && get_lan_ip_info
	[ -z "$lanip" -o -z "$lannetmask" ] && return
	get_guest_ip_info
	[ -z "$guestip" -o -z "$guestnetmask" ] && {
		[ -z "$3" -o -z "$4" ] && echo "0.0.0.0" && return
		guest_exist=0
		guestip=$3
		guestnetmask=$4
	}

	local lanip_int=$(ip_aton $lanip)
	local lannetmask_int=$(ip_aton $lannetmask)
	local guestip_int=$(ip_aton $guestip)
	local guestnetmask_int=$(ip_aton $guestnetmask)
	local newip=$guestip

	local res=$(is_same_subnet $guestip_int $lanip_int $guestnetmask_int $lannetmask_int)
	[ "$res" = "1" ] && {
		local newip_int=$(get_new_ip $guestip_int $guestnetmask $lannetmask 12)
		[ "$newip_int" = "0" ] && {
			log "calc newip for guest failed(guestnetmask=$guestnetmask, lannetmask=$lannetmask)!"
			echo "0.0.0.0" && return
		}

		get_wan_ip_info
		[ -n "$wanip" -a -n "$wannetmask" ] && {
			[ $lannetmask_int -lt $guestnetmask_int] && {
				guestnetmask_int=$lannetmask_int
				guestnetmask=$lannetmask
			}
			res=$(is_same_subnet $newip_int $wanip_int $guestnetmask_int $wannetmask_int)
			[ "$res" = "1" ] && {
				newip_int=$(get_new_ip $guestip_int $guestnetmask $wannetmask 16)
				[ "$newip_int" = "0" ] && {
					log "calc newip for guest failed(guestnetmask=$guestnetmask, wannetmask=$wannetmask)!"
					echo "0.0.0.0" && return
				}
			}
		}

		newip=$(ip_ntoa newip_int)
		[ $guest_exist -eq 1 ] && {
			uci set network.guest.ipaddr=$newip
			uci commit network
			log "change guest ipaddr to $newip"
		}
	}

	echo $newip
}

restart_service() {
	sleep 4
	/etc/init.d/network restart 2>/dev/null
	/etc/init.d/dnsmasq stop 2>/dev/null
	/etc/init.d/dnsmasq restart 2>/dev/null
	/usr/sbin/dhcp_apclient.sh restart 2>/dev/null
	/etc/init.d/trafficd restart 2>/dev/null
	/etc/init.d/minet restart 2>/dev/null
	/usr/sbin/shareUpdate -b 2>/dev/null
	/etc/init.d/mosquitto restart 2>/dev/null
	/etc/init.d/xq_info_sync_mqtt restart 2>/dev/null
}


[ $# -lt 1 ] && usage && exit 1
opt=$1
shift

case $opt in
	newlanip)
		ip_conflict_resolution
		;;
	lanwan)
		ip_conflict_detection
		;;
	miot)
		miot_conflict_resolution $@
		;;
	guest)
		guest_conflict_resolution $@
		;;
	restart_service)
		restart_service
		;;
	*)
		usage
		;;
esac
