#!/bin/sh

###########################
# Some variables
###########################

# Il path di $IPT
IPT="/sbin/iptables"
IPTABLES=$IPT

# external network interface
IFACE=eth0
# external network interface
PUB_IF=eth0

MYNET1=172.9.12.0/24
MYNODE1=172.9.12.223

TRUSTED_NODES=172.9.12.223,\
192.168.15.203,192.168.15.1,192.168.15.98

# comalca tunnel
TRUSTED_NETWORK_1=172.31.0.0/16,172.23.0.0/16
TRUSTED_IF=pptp_smc+,tun_arpac_inc,eth0.4,arif

SSH_PORT=22

# nota 224.0.0.0 è igmp multicast :)
FAKE_NODES=10.0.0.0/8,\
169.254.0.0/16,\
172.16.0.0/12,\
127.0.0.0/8,\
224.0.0.0/4,\
240.0.0.0/5,\
0.0.0.0/8,\
239.255.255.0/24,\
255.255.255.255

set -x

########################
# Un messaggio di avvio
########################

echo " Loading $IPT rules..."
echo " My net is: $MYNET1"
echo " My node is: $MYNODE1"
echo " My trusted nodes are: $TRUSTED_NODES"

modprobe ip_conntrack_ftp
modprobe ip_gre

#####################################
# Pulisco la configurazione corrente
#####################################

# Cancellazione delle regole presenti nelle chains
$IPT -F
$IPT -F -t nat

# Eliminazione delle chains non standard vuote
$IPT -X

##############################
# Creo le mie chains
##############################

$IPT -N INDESIDERATI
$IPT -N ICMP
$IPT -N PORTSCANNERS
$IPT -N UDP
$IPT -N TCP_SERVICES

##############################
# Abilito il traffico locale
##############################

$IPT -A INPUT -i lo -j ACCEPT
$IPT -A OUTPUT -o lo -j ACCEPT
$IPT -A INPUT -s $MYNODE1 -j ACCEPT

# priorità per le connessioni  in corso...
$IPT -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT

# GRE per PPTP
$IPT -A INPUT -p gre  -j ACCEPT
$IPT -A FORWARD -p gre  -j ACCEPT


##############################
# pacchetti contraffatti
##############################
#$IPT -A INPUT   -m state --state INVALID -j DROP
#$IPT -A FORWARD -m state --state INVALID -j DROP
#$IPT -A OUTPUT  -m state --state INVALID -j DROP



##############################
# evitiamo i soliti ingoti ...
##############################
#$IPT -A INPUT -j INDESIDERATI
$IPT -A INDESIDERATI  -s $FAKE_NODES  -j DROP
$IPT -A INDESIDERATI  -d $FAKE_NODES  -j DROP

##############################
# evitiamo i pacchetti ideati per farmi dannare
##############################
##############################
echo "DoS filters"

$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags ALL FIN,URG,PSH -j DROP
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags ALL ALL -j DROP
 
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags ALL NONE -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "NULL Packets"
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags ALL NONE -j DROP # NULL packets
 
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags SYN,RST SYN,RST -j DROP
 
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags SYN,FIN SYN,FIN -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "XMAS Packets"
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags SYN,FIN SYN,FIN -j DROP #XMAS
 
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags FIN,ACK FIN -m limit --limit 5/m --limit-burst 7 -j LOG --log-level 4 --log-prefix "Fin Packets Scan"
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags FIN,ACK FIN -j DROP # FIN packet scans
 
$IPT  -A INPUT -i ${PUB_IF} -p tcp --tcp-flags ALL SYN,RST,ACK,FIN,URG -j DROP

# and again
$IPT -A INPUT -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,SYN,RST,PSH,ACK,URG NONE -j DROP
$IPT -A INPUT -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,SYN FIN,SYN -j DROP
$IPT -A INPUT -i ${PUB_IF} -p tcp -m tcp --tcp-flags SYN,RST SYN,RST -j DROP
$IPT -A INPUT -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,RST FIN,RST -j DROP
$IPT -A INPUT -i ${PUB_IF} -p tcp -m tcp --tcp-flags FIN,ACK FIN -j DROP
$IPT -A INPUT -i ${PUB_IF} -p tcp -m tcp --tcp-flags ACK,URG URG -j DROP

##############################
# evitiamo gli attacchi smurf che disconnettono tutto da tutti
##############################
$IPT -A INPUT -p tcp -m tcp --tcp-flags RST RST -m limit --limit 2/second --limit-burst 2 -j ACCEPT
$IPT -A INPUT -p tcp -m tcp --tcp-flags RST RST             -j DROP


##############################
# everything by our friends
##############################
$IPT -A INPUT -s $TRUSTED_NODES -j ACCEPT

# ICMP
$IPT -A INPUT -p ICMP -j ICMP

# all but the floods :)
$IPT -A ICMP -p icmp -m limit --limit  1/s --limit-burst 1 -j ACCEPT
#$IPT -A ICMP -p icmp --icmp-type echo-reply   -m limit --limit  1/s --limit-burst 1 -j ACCEPT
#$IPT -I ICMP 1 -p icmp --icmp-type 8 -m limit --limit  1/s --limit-burst 1 -j ACCEPT
$IPT -A ICMP -j DROP


# filtro sugli UDP
$IPT -A INPUT -p udp -j UDP
$IPT -A UDP -p udp --sport 53 -j ACCEPT
# accetto solo di parlare con un DNS
$IPT -A UDP -p udp -j DROP


##############################
# Tento di isolare i portscans in una chain per gestirle ad-hoc
# tutte le connessioni UDP/TCP le tratto con un burst, se questo venisse superato: LOGGO e DROPPO, è un portscan !
# dopo un limit/burst seguono 20 minuti di buio totale
##############################

$IPT -A INPUT -j PORTSCANNERS
# burst ampio
$IPT -A PORTSCANNERS  -j LOG --log-prefix "CONNECTION " --log-level 4 -m limit --limit 1/minute --limit-burst 5
# sperimentale
#$IPT -A PORTSCANNERS  -p tcp --syn -m limit --limit 1/s --limit-burst 3 -j RETURN
#$IPT -A PORTSCANNERS  -j DROP


# inizio porte riservate Servizi
$IPT -A INPUT -p tcp  -j TCP_SERVICES


# SERVIZI
#$IPT -A TCP_SERVICES -p tcp -m tcp --dport 25 -j ACCEPT
$IPT -A TCP_SERVICES -p tcp -m tcp --dport 80 -j ACCEPT
$IPT -A TCP_SERVICES -p tcp -m tcp --dport 9000 -j ACCEPT
$IPT -A TCP_SERVICES -p tcp -m tcp --dport 8000 -j ACCEPT
$IPT -A TCP_SERVICES -p tcp -m tcp --dport 8002 -j ACCEPT

# SSH
$IPT -A TCP_SERVICES -p tcp -m tcp --dport $SSH_PORT --syn -j LOG --log-prefix "incoming SSH CONNECTION " --log-level 4 -m limit --limit 1/minute --limit-burst 5
#$IPT -A TCP_SERVICES -p tcp -m tcp --dport 2222 -j ACCEPT
# in ssh accettiamo max 10 connessioni ogni 2 minuti
$IPT -A TCP_SERVICES -p tcp --dport $SSH_PORT -m state --state NEW -m recent --name sshguys  --update --seconds 120 --hitcount 11 -j DROP
$IPT -A TCP_SERVICES -p tcp --dport $SSH_PORT -m state --state NEW,ESTABLISHED -m recent --name sshguys --set -j ACCEPT

# loggo a caso connessioni di porte usate spesso dai portscanners
$IPT -A TCP_SERVICES -p tcp -m tcp --dport 5190 -j LOG --log-prefix "Connessione su PORTA rAnDoM molto strana (NMAP ?)" --log-level 4 -m limit --limit 1/second --limit-burst 1
$IPT -A TCP_SERVICES -p tcp -m tcp --dport 1863 -j LOG --log-prefix "Connessione su PORTA rAnDoM molto strana (NMAP ?)" --log-level 4 -m limit --limit 1/second --limit-burst 1


##############################
# Infine mando tutto a quel paese
##############################
$IPT -A INPUT -j REJECT

#$IPT -A SERVICES -p tcp -m tcp --dport 443 -j ACCEPT
#$IPT -A SERVICES -p tcp -m tcp --dport 631 -j DROP
#$IPT -A SERVICES -p tcp -m tcp --dport 995 -j DROP

#samba
#$IPT -A SERVICES -p tcp -m tcp --dport 139 -j DROP
#$IPT -A SERVICES -p tcp -m tcp --dport 137 -j DROP
#$IPT -A SERVICES -p tcp -m tcp --dport 138 -j DROP
#$IPT -A SERVICES -p tcp -m tcp --dport 445 -j DROP
# portmap
#$IPT -A SERVICES -p tcp -m tcp --dport 111 -j DROP

# postgresql
#$IPT -A SERVICES -p tcp -m tcp --dport 5432 -j DROP

$IPT -A OUTPUT -p icmp --icmp-type echo-request  -m limit --limit  1/s --limit-burst 1 -j ACCEPT
#$IPT -A OUTPUT  -s $FAKE_NODES  -j DROP

$IPT -A FORWARD -m state --state ESTABLISHED,RELATED -j ACCEPT
$IPT -A FORWARD -d 255.255.255.255 -j DROP
$IPT -A FORWARD -d 160.97.12.255 -j DROP

#$IPT -A FORWARD -s $TRUSTED_NODES -o any -j ACCEPT

# easy forward from lan to wan for all trusted network and interfaces
for i in $(echo $TRUSTED_IF | sed "s/,/ /g"); 
do 
    for e in $(echo $TRUSTED_NODES | sed "s/,/ /g"); 
    do 
    $IPT -A FORWARD -s $e -o $i -j ACCEPT; 
    done;    
    $IPT -A FORWARD -s $TRUSTED_NETWORK_1 -o $i -j ACCEPT; 
    
done


$IPT -A FORWARD -j DROP



# NAT verso COMALCA
$IPT -t nat -F
$IPT -t nat -X

# arpac
$IPT -t nat -A POSTROUTING -s $TRUSTED_NODES -d 192.168.0.0/24 -o tun_arpac_inc -j MASQUERADE
$IPT -t nat -A POSTROUTING -s $TRUSTED_NODES -d 192.168.120.0/24 -o tun_arpac_inc -j MASQUERADE

# arif
$IPT -t nat -A POSTROUTING -s $TRUSTED_NODES -d 10.1.209.0/24 -o arif -j MASQUERADE
$IPT -t nat -A POSTROUTING -s $TRUSTED_NODES -d 10.1.210.0/24 -o arif -j MASQUERADE

$IPT -I FORWARD 1 -i arif -o eth0.4 -p tcp --syn --dport 80 -m conntrack --ctstate NEW -j ACCEPT

# already configured by for loop
#$IPT -A FORWARD -i eth0.4 -o arif -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
#$IPT -A FORWARD -i arif -o eth0.4 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

$IPT -t nat -A PREROUTING -i arif -p tcp -s 10.1.210.0/24 -d 172.23.21.200 --dport 80 -j DNAT --to-destination 192.168.15.203:80
$IPT -t nat -A PREROUTING -i arif -p tcp -s 10.1.209.0/24 -d 172.23.21.200 --dport 80 -j DNAT --to-destination 192.168.15.203:80
# full nat
#$IPT -t nat -A POSTROUTING -o arif -p tcp --dport 80 -d 192.168.15.203 -j SNAT --to-destination 172.23.21.200

#  LAO_SMC routing
#$IPT -t nat -A POSTROUTING -s 160.97.12.222  -d 192.168.21.0/24 -o ppp0 -j MASQUERADE
#$IPT -t nat -A POSTROUTING -s 160.97.12.222 -d 100.102.0.1/32  -o ppp0 -j MASQUERADE

tate --state NEW --dport 22 -m recent --set -j ACCEPT

#STUFFS 
SYSCTL=/sbin/sysctl

########## IPv4 networking start ##############
# Send redirects, if router, but this is just server
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
 
# Accept packets with SRR option? No
net.ipv4.conf.all.accept_source_route = 0
 
# Accept Redirects? No, this is not router
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
 
# Log packets with impossible addresses to kernel log? yes
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
 
# Ignore all ICMP ECHO and TIMESTAMP requests sent to it via broadcast/multicast
net.ipv4.icmp_echo_ignore_broadcasts = 1
 
# Prevent against the common 'syn flood attack'
net.ipv4.tcp_syncookies = 1
 
# Enable source validation by reversed path, as specified in RFC1812
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

$SYSCTL -w net.ipv4.tcp_syncookies=1
$SYSCTL -w net.ipv4.tcp_fin_timeout=10
$SYSCTL -w net.ipv4.ip_forward=1
$SYSCTL -w net.ipv4.conf.all.log_martians=1 
$SYSCTL -w net.ipv4.conf.default.log_martians=1
#sysctl -w net.ipv4.conf.ppp0.forwarding=1
$SYSCTL -w net.ipv4.icmp_echo_ignore_broadcasts=1

# Controls source route verification
net.ipv4.conf.default.rp_filter = 1

# Controls the System Request debugging functionality of the kernel
kernel.sysrq = 0
 
# Controls whether core dumps will append the PID to the core filename
# Useful for debugging multi-threaded applications
kernel.core_uses_pid = 1
 
# Controls the use of TCP syncookies
#net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2

########## IPv6 networking start ##############
# Number of Router Solicitations to send until assuming no routers are present.
# This is host and not router
net.ipv6.conf.default.router_solicitations = 0
 
# Accept Router Preference in RA?
net.ipv6.conf.default.accept_ra_rtr_pref = 0
 
# Learn Prefix Information in Router Advertisement
net.ipv6.conf.default.accept_ra_pinfo = 0
 
# Setting controls whether the system will accept Hop Limit settings from a router advertisement
net.ipv6.conf.default.accept_ra_defrtr = 0
 
#router advertisements can cause the system to assign a global unicast address to an interface
net.ipv6.conf.default.autoconf = 0
 
#how many neighbor solicitations to send out per address?
net.ipv6.conf.default.dad_transmits = 0
 
# How many global unicast IPv6 addresses can be assigned to each interface?
net.ipv6.conf.default.max_addresses = 1

 
#Enable ExecShield protection
kernel.exec-shield = 1
kernel.randomize_va_space = 1
 
# TCP and memory optimization 
# increase TCP max buffer size setable using setsockopt()
#net.ipv4.tcp_rmem = 4096 87380 8388608
#net.ipv4.tcp_wmem = 4096 87380 8388608
 
# increase Linux auto tuning TCP buffer limits
#net.core.rmem_max = 8388608
#net.core.wmem_max = 8388608
#net.core.netdev_max_backlog = 5000
#net.ipv4.tcp_window_scaling = 1
 
# increase system file descriptor limit    
fs.file-max = 65535
 
#Allow for more PIDs 
kernel.pid_max = 65536
 
#Increase system IP port limits
net.ipv4.ip_local_port_range = 2000 65000
