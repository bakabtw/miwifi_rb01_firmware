#!/bin/sh

wan_device=$(uci get network.wan.ifname)
[ "$wan_device" == "" ] && wan_device="eth1"
lan_device=$(uci get network.lan.ifname)
[ "$lan_device" == "" ] && lan_device="eth0"

save_value() {
    export VALUE_${1}=${2}
}

get_value() {
    eval export "${1}=\${VALUE_${2}:-\${3}}"
}

bridgeap_connect_init() {
    untag_wan_port
}

bridgeap_connect_deinit() {
    recover_wan_port
}

###
# @description: untag wan port if Internet vlan is enabled, then we can send packets without vlan tag.
# @param  {*} nothing
# @return {*} 0 success or 1 failure
###
untag_wan_port() {
    local vlan_internet_enabled=$(uci -q get vlan_service.Internet.enable)
    [ "$vlan_internet_enabled" -ne 1 ] && return 0
    local wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
    local wan_cpu_port=$(uci -q get misc.sw_reg.sw_wan_cpu_port)
    local wan_vlan_id=$(uci -q get vlan_service.internet.vid)
    save_value wan_vlan_ports $(swconfig dev switch0 vlan ${wan_vlan_id} get ports)
    swconfig dev switch0 vlan ${wan_vlan_id} set ports "${wan_port} ${wan_cpu_port}t"
    swconfig dev switch0 set apply
}

###
# @description: called after untag_wan_port function, recover wan vlan tag
# @param  {*} nothing
# @return {*} 0 success or 1 failure
###
recover_wan_port() {
    #local vlan_internet_enabled=$(uci -q get vlan_service.Internet.enable)
    #[ "$vlan_internet_enabled" -ne 1 ] && return 0
    #get_value vlan_ports wan_vlan_ports
    #local wan_vlan_id=$(uci -q get vlan_service.internet.vid)
    #swconfig dev switch0 vlan ${wan_vlan_id} set ports "${vlan_ports}"
    #swconfig dev switch0 set apply

    # reload switch config from /etc/config/network
    swconfig dev switch0 load network
}

# disable superlan
SUPPORT_SUPERLAN=0

log() {
    echo "[network_func] $@" >/dev/console
}

wifiap_open() {
    log "#######################bridgeap_open_rb01###############"
    /usr/sbin/vlan_service.sh stop false
    local wanmac=$(getmac wan)

    uci -q batch <<-EOF >/dev/null
        delete network.wan
        delete network.wan_6
        delete network.vpn
        set network.lan.ifname='eth0 eth1'
        set network.@device[0].macaddr=$wanmac
        delete network.lan.ip6class
        delete network.lan.ip6assign
        delete network.lan.ip6addr
        delete network.lan.ipv6
        commit network

        set dhcp.lan.ignore=1;
        commit dhcp
EOF
}

wifiap_close_default() {
    log "#######################wifiap_close_default###############"
    uci -q batch <<-EOF >/dev/null
    delete network
    set network.lan_dev=device
    set network.lan_dev.name='eth0'
    set network.wan_dev=device
    set network.wan_dev.name='eth1'
    set network.wan_dev.keepup='1'
    set network.switch0=switch
    set network.switch0.name='switch0'
    set network.switch0.reset='1'
    set network.switch0.enable_vlan='1'
    set network.@switch_vlan[0]=switch_vlan
    set network.@switch_vlan[0].device='switch0'
    set network.@switch_vlan[0].vlan='1'
    set network.@switch_vlan[0].ports='1 5'
    set network.@switch_vlan[1]=switch_vlan
    set network.@switch_vlan[1].device='switch0'
    set network.@switch_vlan[1].vlan='2'
    set network.@switch_vlan[1].ports='2 3 4 6'
    set network.loopback=interface
    set network.loopback.ifname='lo'
    set network.loopback.proto='static'
    set network.loopback.ipaddr='127.0.0.1'
    set network.loopback.netmask='255.0.0.0'
    set network.lan=interface
    set network.lan.type='bridge'
    set network.lan.ifname='eth0'
    set network.lan.proto='static'
    set network.lan.ipaddr='192.168.31.1'
    set network.lan.netmask='255.255.255.0'
    set network.wan=interface
    set network.wan.proto='dhcp'
    set network.wan.ifname='eth1'
    set network.miot=interface
    set network.miot.ifname='wl13'
    set network.miot.type='bridge'
    set network.miot.proto='static'
    set network.miot.ipaddr='192.168.32.1'
    set network.miot.netmask='255.255.255.0'
    commit network

    delete dhcp.lan.ignore;
    commit dhcp
EOF
}

wifiap_close() {

    log "#######################wifiap_close###############"

    local router_backup_file="/etc/config/.network.mode.router"

    [ ! -f "$router_backup_file" ] && wifiap_close_default && {
        /usr/sbin/vlan_service.sh restart false
        return
    }

    mv $router_backup_file "/etc/config/network"

    uci -q batch <<-EOF >/dev/null
        delete network.wan.auto
        delete network.wan_6.auto
        commit network
        delete dhcp.lan.ignore;
        commit dhcp
EOF
    /usr/sbin/vlan_service.sh restart false
}

bridgeap_open() {
    log "#######################bridgeap_open_rb01###############"
    /usr/sbin/vlan_service.sh stop false
    local wanmac=$(getmac wan)

    uci -q batch <<-EOF >/dev/null
        delete network.wan
        delete network.wan_6
        delete network.vpn
        set network.lan.ifname='eth0 eth1'
        set network.@device[0].macaddr=$wanmac
        delete network.lan.ip6class
        delete network.lan.ip6assign
        delete network.lan.ip6addr
        delete network.lan.ipv6
        commit network

        set dhcp.lan.ignore=1;
        commit dhcp
EOF
}

bridgeap_close_default() {
    log "#######################bridgeap_close_rb01_default###############"
    uci -q batch <<-EOF >/dev/null
    delete network
    set network.lan_dev=device
    set network.lan_dev.name='eth0'
    set network.wan_dev=device
    set network.wan_dev.name='eth1'
    set network.wan_dev.keepup='1'
    set network.switch0=switch
    set network.switch0.name='switch0'
    set network.switch0.reset='1'
    set network.switch0.enable_vlan='1'
    set network.@switch_vlan[0]=switch_vlan
    set network.@switch_vlan[0].device='switch0'
    set network.@switch_vlan[0].vlan='1'
    set network.@switch_vlan[0].ports='1 5'
    set network.@switch_vlan[1]=switch_vlan
    set network.@switch_vlan[1].device='switch0'
    set network.@switch_vlan[1].vlan='2'
    set network.@switch_vlan[1].ports='2 3 4 6'
    set network.loopback=interface
    set network.loopback.ifname='lo'
    set network.loopback.proto='static'
    set network.loopback.ipaddr='127.0.0.1'
    set network.loopback.netmask='255.0.0.0'
    set network.lan=interface
    set network.lan.type='bridge'
    set network.lan.ifname='eth0'
    set network.lan.proto='static'
    set network.lan.ipaddr='192.168.31.1'
    set network.lan.netmask='255.255.255.0'
    set network.wan=interface
    set network.wan.proto='dhcp'
    set network.wan.ifname='eth1'
    set network.miot=interface
    set network.miot.ifname='wl13'
    set network.miot.type='bridge'
    set network.miot.proto='static'
    set network.miot.ipaddr='192.168.32.1'
    set network.miot.netmask='255.255.255.0'
    commit network

    delete dhcp.lan.ignore;
    commit dhcp

EOF
}

bridgeap_close() {
    log "#######################bridgeap_close_rb01###############"

    local router_backup_file="/etc/config/.network.mode.router"

    [ ! -f "$router_backup_file" ] && bridgeap_close_default && {
        /usr/sbin/vlan_service.sh restart false
        return
    }

    mv $router_backup_file "/etc/config/network"

    uci -q batch <<-EOF >/dev/null
        delete network.wan.auto
        delete network.wan_6.auto
        commit network
        delete dhcp.lan.ignore;
        commit dhcp
EOF
    /usr/sbin/vlan_service.sh restart false
}

network_re_mode() {
    log "=== set re mode config ==="
    uci -q batch <<-EOF >/dev/null
        delete network.wan
        delete network.wan_6
        delete network.vpn
        delete network.lan.ip6class
        delete network.lan.ip6assign
        delete network.lan.ip6addr
        delete network.lan.ipv6
        delete network.@switch_vlan[3]
        delete network.@switch_vlan[2]
        delete network.@switch_vlan[1]
        delete network.@switch_vlan[0]
        set network.switch0.enable_vlan='1'
        set network.port_2=interface
        set network.port_2.ifname='eth0.1'
        set network.port_3=interface
        set network.port_3.ifname='eth0.2'
        set network.port_4=interface
        set network.port_4.ifname='eth0.3'
        set network.ppd_if=interface
        set network.ppd_if.ifname='eth0.999'
        set network.ppd_if.keepup='1'
        add network switch_vlan
        set network.@switch_vlan[0].device='switch0'
        set network.@switch_vlan[0].vlan='1'
        set network.@switch_vlan[0].ports='2 6t'
        add network switch_vlan
        set network.@switch_vlan[1].device='switch0'
        set network.@switch_vlan[1].vlan='2'
        set network.@switch_vlan[1].ports='3 6t'
        add network switch_vlan
        set network.@switch_vlan[2].device='switch0'
        set network.@switch_vlan[2].vlan='3'
        set network.@switch_vlan[2].ports='4 6t'
        add network switch_vlan
        set network.@switch_vlan[3].device='switch0'
        set network.@switch_vlan[3].vlan='4'
        set network.@switch_vlan[3].ports='1 5'
        set network.lan.ifname='eth1 eth0.1 eth0.2 eth0.3 eth0.999'
        commit network

        set dhcp.lan.ignore=1;
        commit dhcp
EOF
}

# lan1 lan2 lan3 <--> cpu port 6
# 			wan	 <--> cpu port 5
network_router_default() {
    local reload_need="$1"

    [ "1" == "$(uci -q get network.@switch_vlan[0].vlan)" -a \
        "1 5" == "$(uci -q get network.@switch_vlan[0].ports)" -a \
        "2" == "$(uci -q get network.@switch_vlan[1].vlan)" -a \
        "2 3 4 6" == "$(uci -q get network.@switch_vlan[1].ports)" ] && {
        log "=== default router enabled, skip ==="
        return
    }

    log "=== set default router config ==="

    uci -q batch <<-EOF >/dev/null
        delete network.@switch_vlan[3]
        delete network.@switch_vlan[2]
        delete network.@switch_vlan[1]
        delete network.@switch_vlan[0]
        delete network.port_2
        delete network.port_3
        delete network.port_4
        set network.switch0.enable_vlan='1'
        add network switch_vlan
        set network.@switch_vlan[0].device='switch0'
        set network.@switch_vlan[0].vlan='1'
        set network.@switch_vlan[0].ports='1 5'
        add network switch_vlan
        set network.@switch_vlan[1].device='switch0'
        set network.@switch_vlan[1].vlan='2'
        set network.@switch_vlan[1].ports='2 3 4 6'
        set network.lan.ifname='eth0'
        set network.wan.ifname='eth1'
        commit network
EOF

    # set port ifname
    echo eth1 >/proc/portmap/1
    echo 0 >/proc/portmap/2
    echo 0 >/proc/portmap/3
    echo 0 >/proc/portmap/4

    # set eth0 linkup always
    echo eth0 >/proc/portmap/10

    [ "$reload_need" == "1" ] && {
        include /lib/network
        setup_switch
        ubus call network reload
    }
}

enable_superlan() {
    local mode=$(uci -q get xiaoqiang.common.NETMODE)
    local wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
    local wan_link=0
    local proto=""
    local superlan=0

    [ -z "$wan_port" ] && wan_port=1

    wan_link=$(ethstatus | grep "port $wan_port" | grep -q up && echo 1 || echo 0)
    proto=$(uci -q get network.wan.proto)
    wan_6=$(uci -q get network.wan_6)
    wan6=$(uci -q get network.wan6)
    vpn=$(uci -q get network.vpn)

    [ "0" == "$wan_link" ] && {
        [ "dhcp" == "$proto" ] && superlan=1
        [ "pppoe" == "$proto" ] && superlan=1
        [ -n "$wan6" ] && superlan=0
        [ -n "$wan_6" ] && superlan=0
        [ -n "$vpn" ] && superlan=0
        [ "" != "$mode" -a "router" != "$mode" ] && superlan=0
    }
    #log "link=$wan_link proto=$proto wan_6=$wan_6 wan6=$wan6 vpn=$vpn"

    echo $superlan
}

# lan1 <--> cpu port 6
# lan2 lan3 wan	 <--> cpu port 5
network_router_superlan() {
    local reload_need="$1"

    [ "1" != "$(enable_superlan)" ] && {
        log "=== skip superlan config ==="
        return
    }

    [ -n "$(uci -q get network.port_1)" -a \
        -n "$(uci -q get network.port_3)" -a \
        -n "$(uci -q get network.port_4)" ] && {
        log "=== superlan enabled, skip ==="
        return
    }

    log "=== set superlan config ==="

    uci -q batch <<-EOF >/dev/null
        delete network.@switch_vlan[3]
        delete network.@switch_vlan[2]
        delete network.@switch_vlan[1]
        delete network.@switch_vlan[0]
        set network.switch0.enable_vlan='1'
        add network switch_vlan
        set network.@switch_vlan[0].device='switch0'
        set network.@switch_vlan[0].vlan='1'
        set network.@switch_vlan[0].ports='1 5t'
        add network switch_vlan
        set network.@switch_vlan[1].device='switch0'
        set network.@switch_vlan[1].vlan='2'
        set network.@switch_vlan[1].ports='2 6'
        add network switch_vlan
        set network.@switch_vlan[2].device='switch0'
        set network.@switch_vlan[2].vlan='3'
        set network.@switch_vlan[2].ports='3 5t'
        add network switch_vlan
        set network.@switch_vlan[3].device='switch0'
        set network.@switch_vlan[3].vlan='4'
        set network.@switch_vlan[3].ports='4 5t'
        set network.port_1=interface
        set network.port_1.ifname='eth1.1'
        set network.port_3=interface
        set network.port_3.ifname='eth1.3'
        set network.port_4=interface
        set network.port_4.ifname='eth1.4'
        set network.lan.ifname='eth0 eth1.3 eth1.4'
        set network.wan.ifname='eth1.1'
        commit network
EOF

    # set port ifname
    echo eth1.1 >/proc/portmap/1
    echo eth0 >/proc/portmap/2
    echo eth1.3 >/proc/portmap/3
    echo eth1.4 >/proc/portmap/4

    [ "$reload_need" == "1" ] && {
        include /lib/network
        setup_switch
        ubus call network reload
    }
}

network_init_arch() {
    local mode=$(uci -q get xiaoqiang.common.NETMODE)
    local lan_ports=$(uci -q get misc.sw_reg.sw_lan_ports)
    local wan_port=$(uci -q get misc.sw_reg.sw_wan_port)
    local ifname
    # clean up all port map
    for port in 0 1 2 3 4; do
        [ -f /proc/portmap/$port ] && echo 0 >/proc/portmap/$port
    done

    # config wan port map
    ifname=$(uci -q get network.wan_dev.name)
    [ -f /proc/portmap/${wan_port} ] && echo "${ifname}" >/proc/portmap/${wan_port}

    # config lan port map
    case "$mode" in
    "whc_re")
        echo eth0.999 > /proc/portmap/10
        for port in ${lan_ports}; do
            ifname=$(uci -q get network.port_${port}.ifname)
            [ -f /proc/portmap/$port ] && echo "${ifname}" >/proc/portmap/$port
        done
        ;;

    "" | "router")
        # set eth0 linkup always
        echo eth0 >/proc/portmap/10

        # superlan
        [ "1" == "$SUPPORT_SUPERLAN" ] && {
            if [ "1" == "$(enable_superlan)" ]; then
                network_router_superlan 0
            else
                network_router_default 0
            fi
        }
        ;;

    "wifiapmode" | "lanapmode")
        # clean up wan port
        [ -f /proc/portmap/${wan_port} ] && echo 0 >/proc/portmap/${wan_port}

        # set eth0,eth1 linkup always
        echo eth0 >/proc/portmap/10
        echo eth1 >/proc/portmap/10
        ;;

    *) ;;

    esac
}
