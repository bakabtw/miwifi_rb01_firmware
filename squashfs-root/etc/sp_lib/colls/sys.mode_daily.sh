#!/bin/ash

ori=$(uci -q get xiaoqiang.common.NETMODE)

case "$ori" in
	"whc_cap")
		if uci -q get xiaoqiang.common.MESHED|grep -qsx 'YES'; then
			echo "CAP"
		else
			echo "Router"
		fi
		;;
	"whc_re")
		echo "Satellite"
		;;
	"lanapmode")
		if uci -q get xiaoqiang.common.MESHED|grep -qsx 'YES'; then
			echo "CAP"
		else
			echo "AP"
		fi
		;;
	"wifiapmode")
		echo "Repeater"
		;;
	*)
		echo "Router"
		;;
esac
