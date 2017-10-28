# this is a customizable IpTables Chain that could be used to detect and reject bruteforce attack and other resource 
# exaustion problems derived from too many connection from the same src (syn flood, brute force, others).

export IPT=iptables
export SSH_PORT=2222
export HITCOUNT=3 # 2 syn connection (<3)
export SECONDS=20 # in 20 seconds are allowed
export CHAIN_NAME=TCP_max2_20sec

# --rcheck: Check if the source address of the packet is  currently  in  the list.
# --update: Like  --rcheck,  except it will update the "last seen" timestamp if it matches.

# this chain permits a maximum number of connection attempts defined in its vars
$IPT -N $CHAIN_NAME
$IPT -A $CHAIN_NAME -m state --state NEW -m recent --set --name sshguys --rsource
$IPT -A $CHAIN_NAME -m state  --state NEW  -m recent --rcheck --seconds $SECONDS --hitcount $HITCOUNT --rttl --name sshguys --rsource -j LOG --log-prefix "BLOCKED TCP Connection ($CHAIN_NAME)" --log-level 4 -m limit --limit 1/minute --limit-burst 5
$IPT -A $CHAIN_NAME -p tcp -m tcp -m recent --rcheck --seconds $SECONDS --hitcount $HITCOUNT --rttl --name sshguys --rsource -j REJECT --reject-with tcp-reset
$IPT -A $CHAIN_NAME -p tcp -m tcp -m recent --update --seconds $SECONDS --hitcount $HITCOUNT --rttl --name sshguys --rsource -j REJECT --reject-with tcp-reset
$IPT -A $CHAIN_NAME -m state --state NEW,ESTABLISHED  -j ACCEPT

# Apply this policy on every ssh connection
$IPT -A INPUT -p tcp -m tcp --dport $SSH_PORT -j $CHAIN_NAME
