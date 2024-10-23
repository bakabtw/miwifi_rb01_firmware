#!/bin/sh
#logger -p notice -t "hotplug.d" "10-phy_check.sh: run because of $INTERFACE $ACTION"

[ "$INTERFACE" = "wan" -a "$ACTION" = "ifup" ] && {
        wan_speed=$(uci -q get xiaoqiang.common.WAN_SPEED)
        [ ${wan_speed:=0} -eq 0 ] && return

        wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
        [ -z "${wan_port}" ] && return

        cur_wan_speed=$(swconfig dev switch0 port ${wan_port} get link | awk '{print $3}' | tr -d "speed:baseT")
        [ ${cur_wan_speed} != ${wan_speed} ] && {
                . /lib/xq-misc/phy_switch.sh
                sw_set_wan_neg_speed "${wan_speed}"
        }
}
