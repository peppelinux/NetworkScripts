IPT="/sbin/iptables"
IPTABLES=$IPT
PUB_IF=ens33

$IPT -N DOS_FILTER

##############################
# evitiamo i pacchetti ideati per scocciare
##############################
echo "DoS filters"

$IPT -A INPUT -i $PUB_IF -j DOS_FILTER


########################################
# Filtro SMURF, limit prima dei DROP successivi
########################################
$IPT -A DOS_FILTER -p icmp -m icmp --icmp-type address-mask-request -j DROP
$IPT -A DOS_FILTER -p icmp -m icmp --icmp-type timestamp-request -j DROP
$IPT -A DOS_FILTER -p icmp -m icmp -m limit --limit 1/second -j ACCEPT

$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags RST RST -j DROP


###############
# Festa del DROP
###############
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags ALL ALL -j DROP
 
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags ALL NONE -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "NULL Packets"
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags ALL NONE -j DROP # NULL packets
 
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
 
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags SYN,FIN SYN,FIN -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "XMAS Packets"
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP #XMAS
 
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags FIN,ACK FIN -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "Fin Packets Scan"
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags FIN,ACK FIN -j DROP # FIN packet scans
 
$IPT  -A DOS_FILTER -i ${PUB_IF} -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# and again
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP

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


###############################################
# Mi difendo dallo spoofing
###############################################
$IPT -A DOS_FILTER -s 10.0.0.0/8 -j DROP 
$IPT -A DOS_FILTER -s 169.254.0.0/16 -j DROP
$IPT -A DOS_FILTER -s 172.16.0.0/12 -j DROP
$IPT -A DOS_FILTER -s 127.0.0.0/8 -j DROP
$IPT -A DOS_FILTER -s 192.168.0.0/24 -j DROP
$IPT -A DOS_FILTER -s 192.168.1.0/24 -j DROP
$IPT -A DOS_FILTER -s 192.168.10.0/24 -j DROP
$IPT -A DOS_FILTER -s 224.0.0.0/4 -j DROP
$IPT -A DOS_FILTER -d 224.0.0.0/4 -j DROP
$IPT -A DOS_FILTER -s 240.0.0.0/5 -j DROP
$IPT -A DOS_FILTER -d 240.0.0.0/5 -j DROP
$IPT -A DOS_FILTER -s 0.0.0.0/8 -j DROP
$IPT -A DOS_FILTER -d 0.0.0.0/8 -j DROP
$IPT -A DOS_FILTER -d 239.255.255.0/24 -j DROP
$IPT -A DOS_FILTER -d 255.255.255.255 -j DROP
