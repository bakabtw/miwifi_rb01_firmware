#!/bin/sh
# vlan_service

. /lib/functions.sh
. /lib/xq-misc/vlan_service_product.sh

# variable global var
NUM_VID=0
LIST_VID=""
IF_WAN="$STRING_IF_WAN"

FLG_INTERNET_ENABLE="0"
FLG_MULTIMEDIA_ENABLE="0"

LIST_IF_BR_IPTV=""
LIST_IF_BR_VOIP=""
LIST_IF_BR_INTERNET=""
LIST_IF_BR_LAN=""

# const global var
NULL=""
STRING_LIST_PREFIX="LIST_IF_BR_"
LOCK_VLAN_SERVICE="/var/run/vlan_servcie.lock"
LIST_BRIDGE=""iptv" "voip" "internet""

# usage
vs_usage(){
    echo "usage: vlan_service.sh start|stop|restart"
    echo "params format: vlan_service.sh <start|stop|restart>"
    echo "value: start -- start vlan_service.sh"
    echo "value: stop -- stop vlan_service.sh"
    echo "value: restart -- restart vlan_service.sh"
    echo ""
}

# get a available vid num. the num save in "NUM_VID" param
vs_get_unused_vid(){
    let NUM_VID++

    while [ 1 ]; do
        list_contains LIST_VID "$NUM_VID" || break
        let NUM_VID++
    done
    append LIST_VID "$NUM_VID"

    return
}

# collect all used vid num, in case vid alloc conflict
vs_collect_used_vid(){
    collect_vid(){
        local type="$1"
        local vid=$(config_get "$type" vid)
        list_contains LIST_VID "$vid" || append LIST_VID "$vid"
    }
    config_foreach collect_vid type
}

# $1: type
# $2: switch<x>
# $3：ports
# #3: switch vlan vid
# $4: service vid
# $5: ifname
# $6: priority
vs_create_vlan(){
    local type="$1"
    local switch="$2"
    local ports="$3"
    local vid="$4"
    local service_vid="$5"
    local ifname="$6"
    local priority="$7"
    local list_if_name="$STRING_LIST_PREFIX""$(echo "$type" | tr '[a-z]' '[A-Z]')"

    vs_create_switch_vlan "$switch" "$ports" "$vid" "$service_vid"

    list_contains "$list_if_name" "$ifname" || append "$list_if_name" "$ifname"
    [ "$ifname" != "$STRING_IF_WAN" -a "$ifname" != "$STRING_IF_LAN" ] && vs_create_if "$ifname" "$priority"

    vs_logger "create vlan success: ports=$ports, vid=$vid, ifname=$ifname"
    return
}

vs_add_wan_internet_vlan(){
    local vid
    local wan_egress_tag
    local priority
    local wan_port="$STRING_WAN_PORTS"

    vs_get_unused_vid
    if [ "$FLG_INTERNET_ENABLE" = "1" ]; then
        config_get vid "internet" "vid"
        config_get priority "internet" "priority"
        config_get wan_egress_tag "internet" "wan_egress_tag" "1"
        [ -z "$vid" ] && vs_logger "uci config not complete" && return
        #[ "$wan_egress_tag" = "1" ] && wan_port="$wan_port""$TAG"

        IF_WAN="$STRING_IF_WAN"".""$vid"
        vs_create_vlan "internet" "$STRING_WAN_SWITCH" "${wan_port}" "$NUM_VID" "$vid" "${IF_WAN}" "$priority"
    else
        IF_WAN="$STRING_IF_WAN"
        vs_create_vlan "internet" "$STRING_WAN_SWITCH" "${wan_port}" "$NUM_VID" "$NULL" "${IF_WAN}" "$priority"
    fi

    vs_logger "add wan vlan: Internet service success!\n"
    return
}

# $1: lan name, like "lan1"
vs_add_internet_vlan(){
    local lan="$1"
    local port
    local ifname
    local priority
    local lan_egress_tag=""

    # get param from uci config
    config_get port "$lan" "port"
    config_get priority "internet" "priority"
    config_get lan_egress_tag "internet" "lan_egress_tag" "0"
    [ -z "$port" ] && vs_logger "$lan uci config not complete" && return

    port="$STRING_LAN_CPU_PORT_TAG"" $port"
    [ "$lan_egress_tag" = "1" ] && port="$port""$TAG"
    ifname=$(eval echo $"STRING_IF_LAN""${lan:${#lan}}")

    # devide switch vlan and save interface info
    vs_get_unused_vid
    vs_create_vlan "lan" "$STRING_LAN_SWITCH" "$port" "$NUM_VID" "$NULL" "$ifname"".$NUM_VID" "$priority"

    vs_logger "add $lan vlan: type=$type service success!\n"
    return
}

# $1: lan name, like "lan1"
# $2: service type, like "iptv"
vs_add_multimedia_vlan(){
    local lan="$1"
    local type="$2"
    local vid
    local priority
    local lan_port
    local lan_ifname
    local lan_egress_tag
    local wan_egress_tag
    local wan_port="$STRING_WAN_PORTS"

    # get param from uci config
    config_get lan_port "$lan" "port"
    config_get vid "$type" "vid"
    config_get priority "$type" "priority"
    config_get lan_egress_tag "$type" "lan_egress_tag" "0"
    config_get wan_egress_tag "$type" "wan_egress_tag" "1"
    [ -z "$vid" -o -z "$lan_port" ] && vs_logger "$lan or ""$type"" uci config not complete" && return

    lan_port="$STRING_LAN_CPU_PORT_TAG"" ""$lan_port"
    [ "$lan_egress_tag" = "1" ] && lan_port="$lan_port""$TAG"
    #[ "$wan_egress_tag" = "1" ] && wan_port="$wan_port""$TAG"
    lan_ifname=$(eval echo $"STRING_IF_LAN""${lan:${#lan}}")

    # devide switch vlan and save interface info
    vs_get_unused_vid
    if [ "$vid" = "0" ]; then
        vs_create_vlan "internet" "$STRING_LAN_SWITCH" "$lan_port" "$NUM_VID" "$NULL" "$lan_ifname"".$NUM_VID" "$priority"
        IF_WAN="br-internet"
    else
        vs_create_vlan "$type" "$STRING_LAN_SWITCH" "$lan_port" "$NUM_VID" "$NULL" "$lan_ifname"".$NUM_VID" "$priority"
        vs_create_vlan "$type" "$STRING_WAN_SWITCH" "$wan_port" "$NUM_VID" "$vid" "$STRING_IF_WAN"".$vid" "$priority"
    fi

    vs_logger "add $lan vlan: type=$type service success!\n"
    return
}

# $1: lan namd, like "lan1"
vs_add_bridge_vlan(){
    local lan="$1"
    vs_get_unused_vid

    # save interface info to every list
    for type in $LIST_BRIDGE; do
        local port
        local ifname
        local vid
        local priority
        local lan_egress_tag

        local list_name="$STRING_LIST_PREFIX""$(echo "$type" | tr '[a-z]' '[A-Z]')"
        local list_info=$(eval echo $"$list_name")
        [ -z "$list_info" ] && continue

        config_get vid "$type" "vid"
        config_get priority "$type" "priority"
        config_get port "$lan" "port"
        config_get lan_egress_tag "$lan" "lan_egress_tag" "0"
        [ -z "$vid" -o -z "$port" ] && vs_logger "$type"" uci config not complete" && return

        port="$STRING_LAN_CPU_PORT_TAG"" $port"
        [ "$lan_egress_tag" = "1" ] && port="$port""$TAG"
        ifname=$(eval echo $"STRING_IF_LAN""${lan:${#lan}}")

        if [ "$type" = "internet" -a "$FLG_INTERNET_ENABLE" = "0" ]; then
            vs_create_vlan "$type" "$STRING_LAN_SWITCH" "$port" "$NUM_VID" "$NULL" "$ifname"".$NUM_VID" "$priority"
        else
            vs_create_vlan "$type" "$STRING_LAN_SWITCH" "$port" "$NUM_VID" "$vid" "$ifname"".$vid" "$priority"
        fi
    done

    vs_logger "add $lan vlan: type=bridge service success!\n"
    return
}

# add if and bridge from list
vs_create_all_bridge(){
    local string_if_lan="$STRING_IF_LAN"

    # add br-<service> bridge and interface
    for type in $LIST_BRIDGE; do
        local list_name="$STRING_LIST_PREFIX""$(echo "$type" | tr '[a-z]' '[A-Z]')"
        local list_info=$(eval echo $"$list_name")
        [ -z "$list_info" ] && continue

        [ "$type" = "internet" -a "$IF_WAN" = "$STRING_IF_WAN" ] && continue
        [ "$type" != "internet" -o "$IF_WAN" = "br-internet" ] &&  vs_create_bridge "$type" "$list_name"
    done

    # add br-lan interface
    [ -n "$LIST_IF_BR_LAN" ] && string_if_lan="$LIST_IF_BR_LAN"

    vs_change_wan_if "$IF_WAN"
    vs_change_lan_if "$string_if_lan"
    return
}

# service start, add all vlan
vs_add_vlan(){
    config_get FLG_INTERNET_ENABLE "Internet" "enable" "0"
    config_get FLG_MULTIMEDIA_ENABLE "Multimedia" "enable" "0"
    # [ "$STRING_LAN_SWITCH" = "$STRING_WAN_SWITCH" ] && FLG_DOUBLE_TAG="1"

    if [ "$FLG_INTERNET_ENABLE" = "0" -a "$FLG_MULTIMEDIA_ENABLE" = "0" ]; then
        vs_revert_network
        vs_logger "vlan_service func is disable"
        return
    fi

    # Internet function
    vs_add_wan_internet_vlan

    # Multimedia function
    # deal lan's "iptv" "voip" "internet" service
    deal_service(){
        local lan="$1"
        local type

        config_get type "$lan" "type" "internet"
        [ "$type" = "bridge" ] && [ "$FLG_MULTIMEDIA_ENABLE" = "1" ] && return

        if [ "$FLG_MULTIMEDIA_ENABLE" = "0" -o "$type" = "internet" ]; then
            vs_add_internet_vlan "$lan"
        else
            vs_add_multimedia_vlan "$lan" "$type"
        fi
        return
    }
    config_foreach deal_service interface

    # deal lan's "bridge" service
    deal_bridge(){
        local lan="$1"
        local type

        config_get type "$lan" "type" "internet"
        [ "$type" != "bridge" ] && return

        IF_WAN="br-internet"
        vs_add_bridge_vlan "$lan"
        return
    }
    [ "$FLG_MULTIMEDIA_ENABLE" = "1" ] && config_foreach deal_bridge interface

    # create network interface and bridge from list
    vs_create_all_bridge

    return
}

# service stop, delete all vlan
vs_del_vlan(){
    vs_del_interface
    vs_del_switch_vlan
    return
}

vs_del_interface(){
    # remove interface
    remove_if(){
        local ifname="$1"
        [ "${ifname:0:${#STRING_IFNAME_PREFIX}}" = "$STRING_IFNAME_PREFIX" ] && vs_remove_if "$ifname"
        return
    }
    config_foreach remove_if interface

    # remove bridge
    remove_bridge(){
        local ifname="$1"
        list_contains LIST_BRIDGE "$ifname" && vs_remove_bridge "$ifname"
        return
    }
    config_foreach remove_bridge interface
    return
}

vs_del_switch_vlan(){
    remove_switch_vlan(){
        local switch_vlan_name="$1"
        vs_remove_switch_vlan "$switch_vlan_name"
        return
    }
    config_foreach remove_switch_vlan switch_vlan
    config_foreach remove_switch_vlan switch_ext

    return
}

# vlan service start
vs_start(){
    vs_logger "enter vs_start"

    vs_start_init
    vs_add_vlan

    [ ${RESTART_NETWORK:=true} = "true" ] && vs_restart_network

    vs_logger "quit vs_start\n"
    return
}

# vlan service stop
vs_stop(){
    local flg_simple_stop="$1"

    vs_logger "enter vs_stop"
    vs_stop_init
    vs_del_vlan

    # for simple stop, no need to revert network's config or restart network
    if [ -n "$flg_simple_stop" -a "$flg_simple_stop" = '1' ]; then
        vs_logger "quit vs_stop\n"
        return
    fi

    vs_revert_network
    vs_restart_network

    vs_logger "quit vs_stop\n"
    return
}

# vlan service restart
vs_restart(){
    vs_stop "1"
    sleep 1
    vs_start
    return
}

#------------------- main -------------------#
trap "lock -u $LOCK_VLAN_SERVICE; exit 1" SIGHUP SIGINT SIGTERM
lock $LOCK_VLAN_SERVICE

RESTART_NETWORK="$2"

case "$1" in
    start)
        vs_start
        ;;
    stop)
        vs_stop
        ;;
    restart)
        vs_restart
        ;;
    test)
        vs_test
        ;;
    *)
        vs_usage
        ;;
esac

lock -u $LOCK_VLAN_SERVICE
return 0
