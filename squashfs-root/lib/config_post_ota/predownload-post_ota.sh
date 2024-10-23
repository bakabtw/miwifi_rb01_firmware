#!/bin/ash

readonly CRON_FILE=/etc/crontabs/root
readonly DATA_CRON_FILE=/data/etc/crontabs/root

if grep -qsw otapredownload "$CRON_FILE"; then
	sed -i '/otapredownload/s/^48/1/' $CRON_FILE
fi

if grep -qsw otapredownload "$DATA_CRON_FILE"; then
	sed -i '/otapredownload/s/^48/1/' $DATA_CRON_FILE
fi


