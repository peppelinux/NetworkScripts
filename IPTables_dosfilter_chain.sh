IPT="/sbin/iptables"
IPTABLES=$IPT
PUB_IF=ens33

$IPT -N DOS_FILTER

##############################
# evitiamo i pacchetti ideati per farmi dannare
##############################
##############################
echo "DoS filters"

$IPT -A INPUT -i ens18 -j DOS_FILTER
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

##############################
# evitiamo gli attacchi smurf che disconnettono tutto da tutti
##############################
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT
$IPT -A DOS_FILTER -i ${PUB_IF} -p tcp -m tcp --tcp-flags RST RST -j DROP
