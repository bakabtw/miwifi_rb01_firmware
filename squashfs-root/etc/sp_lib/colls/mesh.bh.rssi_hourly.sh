#!/bin/sh

bh_type=$(topomon_action.sh current_status bh_type)
if [ "${bh_type}" = "wireless" ]; then
	ifname_bh=$(uci -q get wireless.bh_5G_sta.ifname)

	rssi=$(iwinfo "${ifname_bh}" info 2>/dev/null \
			|grep "Signal" \
			|sed 's|dBm||g' \
			|awk '{print $2}')
	echo "${rssi}"
fi
