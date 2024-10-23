#!/bin/ash

ethstatus|grep -vw wan|grep -c up
