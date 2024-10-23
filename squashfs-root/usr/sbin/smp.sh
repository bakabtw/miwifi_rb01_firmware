#!/bin/sh

echo 2 > /sys/class/net/eth0/queues/rx-0/rps_cpus
echo 2 > /sys/class/net/eth0/queues/tx-0/xps_cpus
echo 1 > /sys/class/net/eth1/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/eth1/queues/tx-0/xps_cpus
echo 0 > /sys/class/net/wl1/queues/rx-0/rps_cpus
echo 0 > /sys/class/net/wl14/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/wl0/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/wl0/queues/tx-0/xps_cpus
echo 1 > /sys/class/net/wl5/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/wl5/queues/tx-0/xps_cpus
echo 1 > /sys/class/net/wl9/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/wl9/queues/tx-0/xps_cpus
echo 0 > /sys/class/net/apcli0/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/apclii0/queues/rx-0/rps_cpus
echo 1 > /sys/class/net/apclii0/queues/tx-0/xps_cpus

echo 2 > /proc/irq/252/smp_affinity
echo 1 > /proc/irq/251/smp_affinity
echo 1 > /proc/irq/245/smp_affinity
echo 2 > /proc/irq/247/smp_affinity
echo 2 > /proc/irq/13/smp_affinity
