#!/bin/bash
set -e
set -x

IPT="/sbin/iptables"
IPTABLES=$IPT
PUB_IF=ens33

#######
# creo la chain
#######
$IPT -N DOS_FILTER

##############################
# evitiamo i pacchetti ideati per scocciare
##############################
$IPT -A INPUT -i $PUB_IF -j DOS_FILTER

########################################
# Filtro SMURF, limit prima dei DROP successivi
########################################

# CVE-2019-11479: SACK ddos mitigation
$IPT -A DOS_FILTER -p tcp -m tcpmss --mss 1:500 -j DROP

$IPT -A DOS_FILTER -p icmp -m icmp --icmp-type address-mask-request -j DROP
$IPT -A DOS_FILTER -p icmp -m icmp --icmp-type timestamp-request -j DROP
#$IPT -A DOS_FILTER -p icmp -m icmp -m limit --limit 1/second -j ACCEPT

$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags RST RST -j DROP


###############
# Festa del DROP
###############
$IPT  -A DOS_FILTER -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
$IPT  -A DOS_FILTER -p tcp --tcp-flags ALL ALL -j DROP
 
$IPT  -A DOS_FILTER -p tcp --tcp-flags ALL NONE -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "NULL Packets"
$IPT  -A DOS_FILTER -p tcp --tcp-flags ALL NONE -j DROP # NULL packets
 
$IPT  -A DOS_FILTER -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
 
$IPT  -A DOS_FILTER -p tcp --tcp-flags SYN,FIN SYN,FIN -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "XMAS Packets"
$IPT  -A DOS_FILTER -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP #XMAS
 
$IPT  -A DOS_FILTER -p tcp --tcp-flags FIN,ACK FIN -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "Fin Packets Scan"
$IPT  -A DOS_FILTER -p tcp --tcp-flags FIN,ACK FIN -j DROP # FIN packet scans
 
$IPT  -A DOS_FILTER -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# and again
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
$IPT -A DOS_FILTER -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP

#####################################################
# ICMP Policy
#####################################################
$IPT -A DOS_FILTER -p icmp --icmp-type echo-reply -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A DOS_FILTER -p icmp --icmp-type echo-request -m limit --limit 5/s -m state --state NEW -j ACCEPT
$IPT -A DOS_FILTER -p icmp --icmp-type destination-unreachable -m state --state NEW -j ACCEPT
$IPT -A DOS_FILTER -p icmp --icmp-type time-exceeded -m state --state NEW -j ACCEPT
$IPT -A DOS_FILTER -p icmp --icmp-type timestamp-request -m state --state NEW -j ACCEPT
$IPT -A DOS_FILTER -p icmp --icmp-type timestamp-reply -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A DOS_FILTER -p icmp -m icmp --icmp-type 8 -j ACCEPT
$IPT -A OUTPUT -p icmp -m icmp --icmp-type 8 -j ACCEPT

# https://javapipe.com/blog/iptables-ddos-protection/
### 1: Drop invalid packets ### 
$IPT -t mangle -A PREROUTING -m conntrack --ctstate INVALID -j DROP  

### 2: Drop TCP packets that are new and are not SYN ### 
$IPT -t mangle -A PREROUTING -p tcp ! --syn -m conntrack --ctstate NEW -j DROP 
 
### 3: Drop SYN packets with suspicious MSS value ### 
$IPT -t mangle -A PREROUTING -p tcp -m conntrack --ctstate NEW -m tcpmss ! --mss 536:65535 -j DROP  

### 4: Block packets with bogus TCP flags ### 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,SYN FIN,SYN -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags SYN,RST SYN,RST -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,RST FIN,RST -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags FIN,ACK FIN -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ACK,URG URG -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ACK,FIN FIN -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ACK,PSH PSH -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL ALL -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL NONE -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL FIN,PSH,URG -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,FIN,PSH,URG -j DROP 
$IPT -t mangle -A PREROUTING -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP  

### 5: Block spoofed packets ### 
$IPT -t mangle -A PREROUTING -s 224.0.0.0/3 -j DROP 
$IPT -t mangle -A PREROUTING -s 169.254.0.0/16 -j DROP 
$IPT -t mangle -A PREROUTING -s 172.16.0.0/12 -j DROP 
$IPT -t mangle -A PREROUTING -s 192.0.2.0/24 -j DROP 
$IPT -t mangle -A PREROUTING -s 192.168.0.0/16 -j DROP 
$IPT -t mangle -A PREROUTING -s 10.0.0.0/8 -j DROP 
$IPT -t mangle -A PREROUTING -s 0.0.0.0/8 -j DROP 
$IPT -t mangle -A PREROUTING -s 240.0.0.0/5 -j DROP 
$IPT -t mangle -A PREROUTING -s 127.0.0.0/8 ! -i lo -j DROP  

### 7: Drop fragments in all chains ### 
$IPT -t mangle -A PREROUTING -f -j DROP  

### 8: Limit connections per source IP ### 
$IPT -A DOS_FILTER -p tcp -m connlimit --connlimit-above 111 -j REJECT --reject-with tcp-reset  
  
### 10: Limit new TCP connections per second per source IP ### 
$IPT -A DOS_FILTER -p tcp -m conntrack --ctstate NEW -m limit --limit 60/s --limit-burst 20 -j ACCEPT 
$IPT -A DOS_FILTER -p tcp -m conntrack --ctstate NEW -j DROP  

# 10 or 11...

### 11: Use SYNPROXY on all ports (disables connection limiting rule) ### 
# $IPT -t raw -A PREROUTING -p tcp -m tcp --syn -j CT --notrack 
# $IPT -A DOS_FILTER -p tcp -m tcp -m conntrack --ctstate INVALID,UNTRACKED -j SYNPROXY --sack-perm --timestamp --wscale 7 --mss 1460 
# $IPT -A DOS_FILTER -m conntrack --ctstate INVALID -j DROP

