#!/bin/ash

wanport=$(uci -q get misc.sw_reg.sw_wan_port)
lanport=$(uci -q get misc.sw_reg.sw_lan_ports)

if [ -n "$wanport" ]; then
	speed=$(swconfig dev switch0 port $wanport get link|grep -oE '[0-9]+'|sed '1d')
	if [ -n "$speed" ]; then
		echo "WAN:$speed"
	else
		echo "WAN:0"
	fi
fi

for i in ${lanport}; do
	speed=$(swconfig dev switch0 port $i get link|grep -oE '[0-9]+'|sed '1d')
	if [ -n "$speed" ]; then
		echo "LAN$i:$speed"
	else
		echo "LAN$i:0"
	fi
done
