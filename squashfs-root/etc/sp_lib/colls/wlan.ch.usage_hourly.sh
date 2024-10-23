#!/bin/sh

if [ -d /etc/wireless/mediatek/ ]; then

	chan_util_2G=$(iwpriv wl1 get chanutil 2>/dev/null |awk -F: '{print $2/1000000}')
	chan_util_5G=$(iwpriv wl0 get chanutil 2>/dev/null |awk -F: '{print $2/1000000}')

	echo "2G:${chan_util_2G}"
	echo "5G:${chan_util_5G}"
else
	for band in 2G 5G 5GH; do
		device=$(uci -q get misc.wireless.if_${band})
		if [ -z "$device" ]; then
			continue
		fi

		chan_util=$(iwpriv ${device} g_chanutil 2>/dev/null|awk -F: '{print $2/100}')
		echo "${band}:${chan_util}"
	done
fi
