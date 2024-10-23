#!/bin/sh
# vlan_service

# different product, different value
STRING_IF_WAN="eth1"
STRING_IF_LAN="eth0"
STRING_IF_LAN1="eth0"
STRING_IF_LAN2="eth0"
STRING_IF_LAN3="eth0"

STRING_WAN_SWITCH="switch0"
STRING_WAN_PORT="1"
STRING_WAN_CPU_PORT="5"

STRING_LAN_SWITCH="switch0"
STRING_LAN_CPU_PORT="6"

# const string
TAG="t"
STRING_IFNAME_PREFIX="ifname_"
STRING_SWITCH_VLAN_PREFIX="vlan_"
STRING_WAN_CPU_PORT_TAG="$STRING_WAN_CPU_PORT""$TAG"
STRING_WAN_PORTS="$STRING_WAN_CPU_PORT"" ""$STRING_WAN_PORT"
STRING_WAN_PORTS_TAG="$STRING_WAN_CPU_PORT_TAG"" $STRING_WAN_PORT"
STRING_LAN_CPU_PORT_TAG="$STRING_LAN_CPU_PORT""$TAG"

# variable global var
NUM_VLAN_GROUP_INDEX=0

# print log
vs_logger() {
    echo -e "[vlan_service]------> $1" >/dev/console
    # echo "------> $1" > /tmp/vlan_service.log
    return
}

# for speical product to do some speical action
vs_start_init() {
    # TO DO
    config_load vlan_service
    vs_collect_used_vid
    return
}

# for speical product to do some speical action
vs_stop_init() {
    # TO DO
    config_load network
    return
}

# create network interface
# $1: ifname, like "eth0.1"
# $2: priority
vs_create_if() {
    local if_name="$1"

    # change "eth0.1" to "vlan_eth0_1"
    if_name="$STRING_IFNAME_PREFIX""${if_name//./_}"
    vs_is_config_exist "$if_name" && return

    uci -q batch <<EOF >/dev/null
        set network.$if_name='interface'
        set network.$if_name.ifname="$1"
        set network.$if_name.keepup='1'
        set network.$if_name.priority="$2"
        commit network
EOF
    vs_logger "create if: $1"

    # vif already exists, configure vlan priority
    # because network restart will not create it again
    # then hotplug will not configure vlan priority for it.
    # we need to configure here
    if ifconfig "$1" 2>/dev/null; then
        vconfig set_egress_map $1 0 $2
        vconfig set_ingress_map $1 0 $2
    fi

    return
}

# remove network interface
# $1: ifname, like "iface_eth0_1"
vs_remove_if() {
    local if_name="$1"
    local if_real_name

    # change "iface_eth0_1" to "eth0.1"
    if_real_name="${ifname:${#STRING_IFNAME_PREFIX}}"
    if_real_name="${if_real_name//_/.}"

    uci -q delete network."$ifname"
    vs_logger "remove if: $1"
    return
}

# create network bridge
# $1: bridge name, eg. iptv
# $2: ifname list in this bridge
vs_create_bridge() {
    local br_name="$1"
    local if_list=$(eval echo $"$2")

    vs_is_config_exist "$br_name" && return

    uci -q batch <<EOF >/dev/null
        set network.$br_name='interface'
        set network.$br_name.ifname="$if_list"
        set network.$br_name.type='bridge'
        commit network
EOF

    vs_logger "create bridge: $1 - $if_list"
    return
}

# remove network bridge
# $1: bridge name, eg. iptv
vs_remove_bridge() {
    local br_name="$1"
    uci -q delete network."$br_name"
    vs_logger "remove bridge: ""$1"
    return
}

# devide port in switch
# $1: switch + dev_id, eg. switch1
# $2: ports list, eg. "4t 5t"
# $3: vid
vs_create_switch_vlan() {
    local switch="$1"
    local ports="$2"
    local switch_vlan_name="$STRING_SWITCH_VLAN_PREFIX""$switch"

    for port in $ports; do
        port="${port:0:1}"
        switch_vlan_name="$switch_vlan_name""_p""$port"
    done

    vs_is_config_exist "$switch_vlan_name" && return

    uci -q batch <<EOF >/dev/null
        set network.$switch_vlan_name="switch_vlan"
        set network.$switch_vlan_name.device="$1"
        set network.$switch_vlan_name.ports="$2"
        set network.$switch_vlan_name.vlan="$3"
        commit network
EOF

    vs_logger "create switch vlan: ports=$2, vid=$3"
    return
}

# remove switch vlan
# $1: switch_vlan name in uci config
vs_remove_switch_vlan() {
    local switch_vlan_name="$1"
    uci delete network.$switch_vlan_name
    vs_logger "remove switch vlan: $switch_vlan_name"
    return
}

# revert the network
vs_revert_network() {
    vs_change_wan_if "$STRING_IF_WAN"
    vs_change_lan_if "$STRING_IF_LAN"

    uci -q batch <<EOF >/dev/null
        add network switch_vlan
        set network.@switch_vlan[0].device='switch0'
        set network.@switch_vlan[0].vlan='1'
        set network.@switch_vlan[0].ports='1 5'
        add network switch_vlan
        set network.@switch_vlan[1].device='switch0'
        set network.@switch_vlan[1].vlan='2'
        set network.@switch_vlan[1].ports='2 3 4 6'
        commit network
EOF
    return
}

# change wan's interface in network uci config
# $1: new wan's if
vs_change_wan_if() {
    uci -q set network.wan.ifname="$1"
    uci -q commit network

    vs_is_config_exist "wan_6" && {
        uci -q set network.wan_6.ifname="$1"
        uci -q commit network
    }
    vs_logger "change wan if to: $1"
    return
}

# change lan's interface in network uci config
# $1: new lan's if
vs_change_lan_if() {
    uci -q set network.lan.ifname="$1"
    uci -q commit network
    vs_logger "change lan if to: $1"
    return
}

# restart ports then stations can obtain new IP
vs_restart_ports() {
    local srv_type
    local port
    config_get srv_type "$1" type "internet"
    config_get port "$1" port
    if [ "${srv_type}" != "internet" ]; then
        . /lib/xq-misc/phy_switch.sh
        sw_reneg_ports "${port}"
    fi
}

# restart network
vs_restart_network() {
    uci commit network
    ubus call network reload
    . /lib/network/switch.sh
    setup_switch
    ifup -a -w
    # restart iptv voip bridge ports,
    # then stations can obtain new IP
    config_load vlan_service
    config_foreach vs_restart_ports interface
    return
}

vs_is_config_exist() {
    local config="$1"
    uci -q get network.$config >/dev/null 2>&1
    return $?
}

# used for test
vs_test() {
    vs_del_switch_vlan
}
