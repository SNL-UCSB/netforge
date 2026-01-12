#!/bin/bash
NS1="ns1"
NS2="ns2"
NUM_QUEUE=4
ip netns add $NS1
ip link add veth1 type veth peer name veth2
ip addr add 172.16.1.2/30 dev veth2
ip link set veth2 up

ip link set veth1 netns $NS1
ip netns exec $NS1 ip addr add 172.16.1.1/30 dev veth1
ip netns exec $NS1 ip link set veth1 up
ip netns exec $NS1 ip route add default via 172.16.1.2

sysctl -w net.ipv4.ip_forward=1
iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE
ip netns exec $NS1 sed -i '1s/^/nameserver 8.8.8.8\n /' /etc/resolv.conf
# you can check here that from ns1, the traffic goes to default gateway and comes bach

ip netns add $NS2
sudo ip link add veth3 type veth peer name veth4
# if libreqos is not working, uncomment these
# sudo ip link set veth3 numtxqueues 4 numrxqueues 4
# sudo ip link set veth4 numtxqueues 4 numrxqueues 4

# ip link add veth3 type veth peer name veth4
ip link add veth5 type veth peer name veth6
ip addr add 172.16.2.2/30 dev veth4
ip addr add 172.16.3.2/30 dev veth6
ip link set veth4 up
ip link set veth6 up
ip link set veth3 netns $NS2
ip link set veth5 netns $NS2

ip netns exec $NS2 ip addr add 172.16.2.1/30 dev veth3
ip netns exec $NS2 ip addr add 172.16.3.1/30 dev veth5
ip netns exec $NS2 ip link set veth3 up
ip netns exec $NS2 ip link set veth5 up

ip netns exec $NS2 ip route add default via 172.16.3.2


# next part should double check 

iptables -t nat -A POSTROUTING -o wlp2s0 -j MASQUERADE 
ip netns exec $NS2 iptables -t nat -A POSTROUTING -o veth5 -j MASQUERADE 
ip netns exec $NS2 sed -i '1s/^/nameserver 8.8.8.8\n /' /etc/resolv.conf



ip netns exec $NS1 ip route change default dev veth1
ip netns exec $NS1 ip route change default veth1 via 172.16.3.1 


ip netns exec $NS2 ip route add 172.16.1.0/30 dev veth3 # made it work
ip netns exec $NS2 ip route change default via 172.16.3.2 dev veth5

ethtool -L veth2 tx 64 rx 64
ethtool -L veth4 tx 64 rx 64

# If not using xdp bridge 
BR='LibreBr'
ip link add $BR type bridge
ip link set dev veth2 master $BR
ip link set dev veth4 master $BR
ip link set dev $BR up


################ delete all 
# Delete namespaces
sudo ip netns del ns1
sudo ip netns del ns2

# Delete bridge
sudo ip link del LibreBr

# Delete veth pairs if any remain
sudo ip link del veth1 2>/dev/null
sudo ip link del veth2 2>/dev/null
sudo ip link del veth3 2>/dev/null
sudo ip link del veth4 2>/dev/null
sudo ip link del veth5 2>/dev/null
sudo ip link del veth6 2>/dev/null

# Flush iptables NAT rules added
sudo iptables -t nat -D POSTROUTING -o eno2 -j MASQUERADE 2>/dev/null
sudo iptables -t nat -D POSTROUTING -o wlp2s0 -j MASQUERADE 2>/dev/null
