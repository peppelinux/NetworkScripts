#!/bin/bash
set -e
set -x

IPT="/sbin/iptables"
IPTABLES=$IPT
PUB_IF=ens33
CHAIN=BOGUS_NET

#######
# creo la chain
#######
$IPT -N $CHAIN

###############################################
# Mi difendo dallo spoofing
###############################################
$IPT -A $CHAIN -s 10.0.0.0/8 -j DROP 
$IPT -A $CHAIN -s 169.254.0.0/16 -j DROP
$IPT -A $CHAIN -s 172.16.0.0/12 -j DROP
$IPT -A $CHAIN -s 127.0.0.0/8 -j DROP
$IPT -A $CHAIN -s 192.168.0.0/24 -j DROP
$IPT -A $CHAIN -s 192.168.1.0/24 -j DROP
$IPT -A $CHAIN -s 192.168.10.0/24 -j DROP
$IPT -A $CHAIN -s 224.0.0.0/4 -j DROP
$IPT -A $CHAIN -d 224.0.0.0/4 -j DROP
$IPT -A $CHAIN -s 240.0.0.0/5 -j DROP
$IPT -A $CHAIN -d 240.0.0.0/5 -j DROP
$IPT -A $CHAIN -s 0.0.0.0/8 -j DROP
$IPT -A $CHAIN -d 0.0.0.0/8 -j DROP
$IPT -A $CHAIN -d 239.255.255.0/24 -j DROP
$IPT -A $CHAIN -d 255.255.255.255 -j DROP
