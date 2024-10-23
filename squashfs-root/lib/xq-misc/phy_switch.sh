#!/bin/sh

advcap2bitmap() {
	# Not currently in use, to be done
	:
}

sw_is_wan_2500() {
	false
}

. /lib/functions.sh
config_load misc

USE_AN=1

# power off ports
# $1 ports list, ex: "1 2 3"
sw_poweroff_ports() {
	local ori_value
	local set_value
	for p in $1; do
		# read original value of register 0
		ori_value=$(switch phy cl22 r $p 0 | awk -F'=' '{print $3}')

		# register 0, bit 11 is power down control bit, set to 1
		set_value=$(($ori_value | 0x800))
		switch phy cl22 w $p 0 $set_value
	done
}

# power on ports
# $1 ports list, ex: "1 2 3"
sw_poweron_ports() {
	local ori_value
	local set_value
	for p in $1; do
		# read original value of register 0
		ori_value=$(switch phy cl22 r $p 0 | awk -F'=' '{print $3}')

		# register 0, bit 11 is power down control bit, set to 0
		set_value=$(($ori_value & ~0x800))
		switch phy cl22 w $p 0 $set_value
	done
}

# power off all lan port
sw_stop_lan() {
	config_get lan_ports sw_reg sw_lan_ports
	sw_poweroff_ports "$lan_ports"
}

# power on all lan port
sw_start_lan() {
	config_get lan_ports sw_reg sw_lan_ports
	sw_poweron_ports "$lan_ports"
}

sw_reneg_ports() {
	local ori_value
	local set_value
	for p in $1; do
		# read original value of register 0
		ori_value=$(switch phy cl22 r $p 0 | awk -F'=' '{print $3}')

		# register 0, bit 9 is Restart Auto-Negotiation bit, set to 1
		set_value=$(($ori_value | 0x200))
		switch phy cl22 w $p 0 $set_value
	done
}

# restart all LAN ports
sw_restart_lan() {
	config_get lan_ports sw_reg sw_lan_ports
	sw_reneg_ports "$lan_ports"
}

# restart WAN port
sw_restart_wan() {
	config_get wan_port sw_reg sw_wan_port
	sw_reneg_ports "$wan_port"
}

# Detect link on WAN port
sw_wan_link_detect() {
	config_get wan_port sw_reg sw_wan_port
	swconfig dev switch0 port ${wan_port:=1} get link | grep -q "link:up"
}

# Count link on all LAN port
sw_lan_count() {
	local count=0

	config_get lan_ports sw_reg sw_lan_ports
	for lan_port in $lan_ports; do
		local lanspeed=$(swconfig dev switch0 port $lan_port get link | grep "link:up" | wc -l)
		[ "$lanspeed" != "0" ] && count=$(expr $count + 1)
	done

	echo $count
}

# is wan port enabled gigabytes?
sw_is_wan_giga() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value
	local isGiGa=0

	# read original value of register 0 Mode Control Register
	ori_value=$(switch phy cl22 r $wan_port 0 | awk -F'=' '{print $3}')

	# bit 12 is Auto-negotiation Enable
	if [ $(($ori_value & 0x1000)) != 0 ]; then
		# Auto-negotiation is enabled
		# read original value of register 9 1000BASE-T Control Register
		ori_value=$(switch phy cl22 r $wan_port 9 | awk -F'=' '{print $3}')
		# bit 8 is 1000M HDX, bit 9 is 1000M FDX
		[ $(($ori_value & 0x300)) != 0 ] && isGiGa=1
	else
		# Auto-negotiation is disabled
		# Forced Speed Selection MSB = bit6, LSB = bit13. 00:10Mbps 01:100Mbps 10:1000Mbps 11:Reserved
		[ $(($ori_value & 0x2040)) != 64 ] || isGiGa=1
	fi
	[ ${isGiGa} -eq 1 ] && true || false
}

# set gigabyte on/off for wan
# sw_set_wan_giga on
# sw_set_wan_giga off
sw_set_wan_giga() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value
	local set_value

	# read original value of register 9 1000BASE-T Control Register
	ori_value=$(switch phy cl22 r $wan_port 9 | awk -F'=' '{print $3}')

	if [ "$1" = 'on' ]; then
		# bit 8 is 1000M HDX, bit 9 is 1000M FDX, both set to 1
		set_value=$(($ori_value | 0x300))
	else
		# bit 8 is 1000M HDX, bit 9 is 1000M FDX, both set to 0
		set_value=$(($ori_value & ~0x300))
	fi

	switch phy cl22 w $wan_port 9 $set_value
}

# set Auto-Negotiation of wan port
# on/off
sw_set_wan_an() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value
	local set_value

	# read original value of register 0 Mode Control Register
	ori_value=$(switch phy cl22 r $wan_port 0 | awk -F'=' '{print $3}')

	# bit 12 is Auto-negotiation Enable
	if [ "$1" = 'on' ]; then
		# set to 1
		set_value=$(($ori_value | 0x1000))
	else
		# set to 0
		set_value=$(($ori_value & ~0x1000))
	fi

	switch phy cl22 w $wan_port 0 $set_value
}

# 100Mb advertisement on WAN port enabled?
sw_is_wan_100m() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value

	# read original value of register 4 Auto-Negotiation Advertisement Register
	ori_value=$(switch phy cl22 r $wan_port 4 | awk -F'=' '{print $3}')
	# bit 7 is 100M HDX, bit 8 is 100M FDX
	[ $(($ori_value & 0x180)) != 0 ] && true || false
}

# 10Mb advertisement on WAN port enabled?
sw_is_wan_10m() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value

	# read original value of register 4 Auto-Negotiation Advertisement Register
	ori_value=$(switch phy cl22 r $wan_port 4 | awk -F'=' '{print $3}')
	# bit 5 is 10M HDX, bit 6 is 10M FDX
	[ $(($ori_value & 0x60)) != 0 ] && true || false
}

# set wan port to 100M or 10M
# disable: both disable
# auto: auto 10/100M
# 10: 10M
# 100: 100M
sw_set_wan_100m() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value
	local set_value

	# read original value of register 4 Auto-Negotiation Advertisement Register
	ori_value=$(switch phy cl22 r $wan_port 4 | awk -F'=' '{print $3}')

	# bit 7 is 100M HDX, bit 8 is 100M FDX
	# bit 5 is 10M HDX, bit 6 is 10M FDX
	case $1 in
	disable)
		# disable 100M, disable 10M
		set_value=$(($ori_value & ~0x180))
		set_value=$(($set_value & ~0x60))
		;;
	auto)
		# enable 100M, enable 10M
		set_value=$(($ori_value | 0x180))
		set_value=$(($set_value | 0x60))
		;;
	10)
		# disable 100M, enable 10M
		set_value=$(($ori_value & ~0x180))
		set_value=$(($set_value | 0x60))
		;;
	100)
		# enable 100M, disable 10M
		set_value=$(($ori_value | 0x180))
		set_value=$(($set_value & ~0x60))
		;;
	*)
		echo "unsupport speed!"
		return 1
		;;
	esac

	switch phy cl22 w $wan_port 4 $set_value
}

# force wan port rate
# 1000: 1000M rate
# 100: 100M rate
# 10: 10M rate
sw_force_wan_rate() {
	config_get wan_port sw_reg sw_wan_port
	local ori_value
	local set_value

	# disable Auto-Negotiation
	sw_set_wan_an off

	# read original value of register 0 Mode Control Register
	ori_value=$(switch phy cl22 r $wan_port 0 | awk -F'=' '{print $3}')

	# Forced Speed Selection MSB = bit6, LSB = bit13. 00:10Mbps 01:100Mbps 10:1000Mbps 11:Reserved
	case $1 in
	10)
		set_value=$(($ori_value & ~0x2040))
		;;
	100)
		set_value=$(($ori_value | 0x2000))
		set_value=$(($set_value & ~0x40))
		;;
	1000)
		set_value=$(($ori_value & ~0x2000))
		set_value=$(($set_value | 0x40))
		;;
	*)
		echo "unsupport speed!"
		return 1
		;;
	esac

	switch phy cl22 w $wan_port 0 $set_value
}

# Limit PHY speed advertisement on WAN port to special speed
# 0: auto
# 10: 10M
# 100: 100M
# 1000: 1000M
# sw_set_wan_neg_speed 0
sw_set_wan_neg_speed() {

	case "$1" in
	0)
		sw_set_wan_an on
		sw_set_wan_100m auto
		sw_set_wan_giga on
		;;
	10)
		if [ "$USE_AN" -eq 1 ]; then
			sw_set_wan_an on
			sw_set_wan_100m 10
			sw_set_wan_giga off
		else
			sw_force_wan_rate 10
		fi
		;;

	100)
		if [ "$USE_AN" -eq 1 ]; then
			sw_set_wan_an on
			sw_set_wan_100m 100
			sw_set_wan_giga off
		else
			sw_force_wan_rate 100
		fi
		;;
	1000)
		if [ "$USE_AN" -eq 1 ]; then
			sw_set_wan_an on
			sw_set_wan_100m disable
			sw_set_wan_giga on
		else
			sw_force_wan_rate 1000
		fi
		;;
	*)
		echo "unsupport speed!"
		return 1
		;;
	esac

	# issue re-negotiat
	if sw_restart_wan; then
		# let phy do re-neg
		[ -z "$1" ] && sleep 2
		echo "set WAN speed to ${1}Mb"
		return 0
	else
		ehco 'renegotiation fail!'
		return 1
	fi

}

# Enable EAPOL frame forwarding between CPU port and WAN port
sw_allow_eapol() {
	# Not currently in use, to be done
	:
}

# Disable EAPOL frame forwarding between CPU port and WAN port
sw_restore_eapol() {
	# Not currently in use, to be done
	:
}
