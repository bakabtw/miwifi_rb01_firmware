#!/bin/ash

topomon_action.sh current_status bh_type \
	|sed 's/wired/wire/'
