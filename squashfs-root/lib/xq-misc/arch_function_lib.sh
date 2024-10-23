###
# @Copyright (C), 2020-2022, Xiaomi CO., Ltd.:
# @Description: this file include lib functions for different models
# @Author: Lin Hongqing
# @Date: 2021-05-26 10:19:25
# @Email: linhongqing@xiaomi.com
# @LastEditTime: 2021-08-02 14:05:20
# @LastEditors: Lin Hongqing
# @History:
###
#!/bin/sh

HNAT_LOCK_FILE=/tmp/lock/hnat_switch.lock
hnat_max_try=3
hnat_try_delay=1

arch_start_hnat() {
    local try_times=0
    local hnat_disabled=0
    local hnat_status=1
    local netmode=$(uci -q get xiaoqiang.common.NETMODE)
    [ -z "${netmode}" ] && netmode="routermode"
    while [ "$try_times" -lt ${hnat_max_try} ]; do
        if [ ${netmode} = "whc_re" ] || [ ${netmode} = "lanapmode" ] || [ ${netmode} = "wifiapmode" ]; then
            hnat_disabled=0
        else
            hnat_disabled=$(uci -q get misc.quickpass.hnat_disabled)
        fi

        # disabled by others, do not enable hnat
        # just set tmp flag
        [ ${hnat_disabled:=0} -ne 0 ] && {
            export hnat_tmp_switch=1
            break
        }

        echo 1 >/sys/kernel/debug/hnat/hook_toggle
        hnat_status=$(cat /sys/kernel/debug/hnat/hook_toggle)
        if [ ${hnat_status} -eq 1 ]; then
            export hnat_tmp_switch=1
            break
        fi
        sleep ${hnat_try_delay}
        try_times=$((${try_times} + 1))
    done
}

arch_stop_hnat() {
    local try_times=0
    local hnat_status=1
    while [ ${try_times} -lt ${hnat_max_try} ]; do
        echo 0 >/sys/kernel/debug/hnat/hook_toggle
        hnat_status=$(cat /sys/kernel/debug/hnat/hook_toggle)
        if [ ${hnat_status} -eq 0 ]; then
            export hnat_tmp_switch=0
            break
        fi
        sleep ${hnat_try_delay}
        try_times=$((${try_times} + 1))
    done
}

arch_restart_ipv6_hnat() {
    local ipv6_mode=$(uci -q get ipv6.settings.mode)
    local ipv6_enable=$(uci -q get ipv6.settings.enabled)
    if [ ${ipv6_mode} = "nat" ] && [ ${ipv6_enable} = "1" ]; then
        echo 0 >/sys/kernel/debug/hnat/ipv6_toggle
    else 
        echo 1 >/sys/kernel/debug/hnat/ipv6_toggle
    fi
}

arch_restart_hnat() {
    arch_stop_hnat
    arch_start_hnat
    arch_restart_ipv6_hnat
}

arch_disable_hnat() {
    local try_times=0
    local hnat_status=1
    local hnat_disabled=0
    while [ ${try_times} -lt ${hnat_max_try} ]; do
        hnat_disabled=$(uci -q get misc.quickpass.hnat_disabled)
        [ ${hnat_disabled:=0} -eq 0 ] && echo 0 >/sys/kernel/debug/hnat/hook_toggle
        hnat_status=$(cat /sys/kernel/debug/hnat/hook_toggle)

        # disable successed, set flag
        if [ ${hnat_status} -eq 0 ]; then
            hnat_disabled=$((${hnat_disabled:=0} + 1))
            uci -q set misc.quickpass.hnat_disabled=${hnat_disabled}
            uci commit misc
            break
        fi
        # otherwise, try again until reach max try count
        sleep ${hnat_try_delay}
        try_times=$((${try_times} + 1))
    done
}

arch_enable_hnat() {

    local try_times=0
    local hnat_status=1
    local hnat_disabled=0
    while [ ${try_times} -lt ${hnat_max_try} ]; do
        hnat_disabled=$(uci -q get misc.quickpass.hnat_disabled)
        # already enabled, do nothing
        [ ${hnat_disabled:=0} -eq 0 ] && break
        hnat_disabled=$((${hnat_disabled} - 1))
        if [ ${hnat_disabled} -eq 0 -a ${hnat_tmp_switch:=1} -eq 1 ]; then
            echo 1 >/sys/kernel/debug/hnat/hook_toggle
            hnat_status=$(cat /sys/kernel/debug/hnat/hook_toggle)
            if [ ${hnat_status} -eq 1 ]; then
                uci -q set misc.quickpass.hnat_disabled=${hnat_disabled}
                uci commit misc
                break
            fi
        else
            uci -q set misc.quickpass.hnat_disabled=${hnat_disabled}
            uci commit misc
            break
        fi

        sleep ${hnat_try_delay}
        try_times=$((${try_times} + 1))
    done
}

arch_disable_ipv6_hnat() {
    echo 0 >/sys/kernel/debug/hnat/ipv6_toggle
}

arch_enable_ipv6_hnat() {
    echo 1 >/sys/kernel/debug/hnat/ipv6_toggle
}

# enable or disable hnat
# on true
# off false
arch_set_hnat() {
    trap "lock -u ${HNAT_LOCK_FILE}; exit 1" SIGHUP SIGINT SIGTERM
    lock ${HNAT_LOCK_FILE}
    case "$1" in
    "on" | "true")
        arch_enable_hnat
        ;;
    "off" | "false")
        arch_disable_hnat
        ;;
    *)
        echo "arch_set_hnat unsupport $1" >/dev/console
        ;;
    esac
    lock -u ${HNAT_LOCK_FILE}
}
