#!/bin/sh

wifi_onlines()
{
    local count_2g=0
    local count_5g=0
    local ifname_2g=$(uci -q get misc.wireless.ifname_2G)
    local ifname_5g=$(uci -q get misc.wireless.ifname_5G)

    count_2g=$(iwinfo $ifname_2g assoc | grep stacount | awk '{print $2}')
    count_5g=$(iwinfo $ifname_5g assoc | grep stacount | awk '{print $2}')

    echo $((count_2g + count_5g))
}

# TODO: 有线下挂设备存在多种特殊情况，目前未包含，具体方案待定
# 可以通过brctl showmacs获取设备总数，需要过滤掉无线设备、re子节点（有线组网）
# 但无法处理re和sta同时通过交换机接入cap/re的情况
eth_onlines()
{
    echo "0"
}

all_onlines()
{
    local wifi_stations=$(wifi_onlines)
    local eth_stations=$(eth_onlines)
    local onlines=$((wifi_stations + eth_stations))

    echo $onlines
}

case $1 in
    all_onlines)
        all_onlines
        return 0
        ;;
    wifi_onlines)
        wifi_onlines
        return 0
        ;;
    *) # default return all_onlines
        all_onlines
        return 0
        ;;
esac
