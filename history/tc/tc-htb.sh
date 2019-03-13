#!/bin/bash
#
#  kb or k: Kilobytes
#  mb or m: Megabytes
#  mbit: Megabits
#  kbit: Kilobits
#  To get the byte figure from bits, divide the number by 8 bit
#
#  ex: tc_htb.sh restart qg-f5f0ed64-84 qrouter-d5b5b595-9ae2-49e9-8fd9-6ddbf6195702
#
TC=/sbin/tc
if [ -n "$3" ]; then
    TC="/sbin/tc -n $3" #tc utility, iproute2-ss150706
fi
IF=$2           # Interface
UPLD=1mbit          # VM UPLOAD Limit
DEF_UPLD=2mbit          # VM UPLOAD Limit
DNLD=10mbit          # VM DOWNLOAD Limit
DEF_DNLD=20mbit          # VM DOWNLOAD Limit
IP=192.168.252.168  # VM IP
GW_IP=192.168.252.141  # Router GW IP
HTB_U32="$TC filter add dev $IF protocol all parent 1: prio 1 u32"
INGRESS_U32="$TC filter add dev $IF protocol all parent ffff:"

start() {
    # UPLOAD TRAFFIC
    $TC qdisc add dev $IF root handle 1: htb default 1000
    $TC class add dev $IF parent 1: classid 1:1000 htb rate $DEF_UPLD #burst 100kb
    $TC qdisc add dev $IF parent 1:1000 handle 1001: sfq perturb 10

    $TC class add dev $IF parent 1: classid 1:1 htb rate $UPLD #burst 100kb
    $TC qdisc add dev $IF parent 1:1 handle 2: sfq perturb 10
    $HTB_U32 match ip src $IP/32 flowid 1:1
    # DOWNLOAD TRAFFIC
    $TC qdisc add dev $IF ingress
    $INGRESS_U32 prio 1 u32 match ip dst $GW_IP/32 police rate $DEF_DNLD burst 512kb mtu 64kb drop flowid :1
    $INGRESS_U32 prio 2 u32 match ip dst $IP/32 police rate $DNLD burst 256kb mtu 64kb drop flowid :1
}
rm() {
    $TC qdisc del dev $IF parent 1:1
    $TC filter del dev $IF protocol all parent 1: prio 1
    $TC class del dev $IF parent 1: classid 1:1
    $TC filter del dev $IF protocol all parent ffff: prio 2

}
stop() {
    $TC qdisc del dev $IF root
    $TC qdisc del dev $IF ingress
}
restart() {
    stop
    sleep 1
    start
}
show() {
    echo '=================================='
    $TC -s -d -p qdisc show dev $IF
    echo '=================================='
    echo -e '\n'
    echo '=================================='
    $TC class show dev $IF
    echo '=================================='
    echo -e '\n'
    echo '=================================='
    $TC -s -d -p filter show dev $IF
    echo '----------------------------------'
    $TC filter show dev $IF parent ffff:
    echo '=================================='
}
case "$1" in
  start)
    echo -n "Starting bandwidth shaping: "
    start
    echo "done"
    ;;
  stop)
    echo -n "Stopping bandwidth shaping: "
    stop
    echo "done"
    ;;
  restart)
    echo -n "Restarting bandwidth shaping: "
    restart
    echo "done"
    ;;

  rm)
    echo -n "Rm bandwidth shaping: "
    rm
    echo "done"
    ;;
  show)

    echo "Bandwidth shaping status for $IF:"
    show
    echo ""
    ;;
  *)
    pwd=$(pwd)
    echo "Usage: $(/usr/bin/dirname $pwd)/tc.bash {start|stop|restart|show}"
    ;;
esac
exit 0
