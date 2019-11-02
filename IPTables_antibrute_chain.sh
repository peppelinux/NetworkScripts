#!/bin/bash
set -e
set -x

IPT="/sbin/iptables"
CHAIN=ANIBRUTEFORCE_TCP
HITCOUNT=3 # 2 syn connection (<3)
SECONDS=20 # in 20 seconds are allowed
SSH_PORT=22

#######
# creo la chain
#######
$IPT -N $CHAIN

# --rcheck: Check if the source address of the packet is  currently  in  the list.
# --update: Like  --rcheck,  except it will update the "last seen" timestamp if it matches.

$IPT -A $CHAIN -p tcp -m tcp --dport $SSH_PORT -m state --state NEW -m recent --set --name sshguys --rsource
$IPT -A $CHAIN -p tcp -m tcp --dport $SSH_PORT -m state  --state NEW  -m recent --rcheck --seconds $SECONDS --hitcount $HITCOUNT --rttl --name sshguys --rsource -j LOG --log-prefix "BLOCKED SSH (brute force)" --log-level 4 -m limit --limit 1/minute --limit-burst 5
$IPT -A $CHAIN -p tcp -m tcp --dport $SSH_PORT -m recent --rcheck --seconds $SECONDS --hitcount $HITCOUNT --rttl --name sshguys --rsource -j REJECT --reject-with tcp-reset
$IPT -A $CHAIN -p tcp -m tcp --dport $SSH_PORT -m recent --update --seconds $SECONDS --hitcount $HITCOUNT --rttl --name sshguys --rsource -j REJECT --reject-with tcp-reset
$IPT -A $CHAIN -p tcp -m tcp --dport $SSH_PORT -m state --state NEW,ESTABLISHED  -j ACCEPT
