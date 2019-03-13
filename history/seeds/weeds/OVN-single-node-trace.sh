#!/bin/bash 

src_ip=$1
dst_ip=$2
if test -z $2; then
    echo "usage $0 src_ip dst_ip"
    exit 2
fi
dst_nw=`mysql -uroot -ppassword "neutron" -e "select cidr from subnets where id in (select subnet_id from ipallocations where ip_address='"$dst_ip"')" | awk '{if(NR>1)print $1}'`

nh_mac=`mysql -uroot -ppassword "neutron" -e "select mac_address from ports where id=(select port_id from ipallocations where ip_address=(select gateway_ip from subnets where id in (select subnet_id from ipallocations where ip_address='"$src_ip"')))" | awk '{if(NR>1)print $1}'`

src_port=`mysql -uroot -ppassword "neutron" -e "select * from ipallocations where ip_address in ('"$src_ip"')" | awk '{if(NR>1)print $1}'`
dst_port=`mysql -uroot -ppassword "neutron" -e "select * from ipallocations where ip_address in ('"$dst_ip"')" | awk '{if(NR>1)print $1}'`

function get_ofport_from_name() {
    sudo ovs-vsctl list Interface $1 | awk '/ofport /{print $3}'
}
sp_ofp=`get_ofport_from_name "tap"${src_port::11}`
dp_ofp=`get_ofport_from_name "tap"${dst_port::11}`

function get_mt_from_inport() {
    sudo ovs-ofctl dump-flows br-int table=0 | grep in_port=$1 | cut -d ':' -f 2 | cut -d '-' -f 1
}
function get_r6_from_inport() {
    sudo ovs-ofctl dump-flows br-int table=0 | grep in_port=$1 | cut -d ':' -f 3 | cut -d '-' -f 1
}
function mt_belongs_to_router_datapath() {
    d=`printf "%d\n" $1`
    ovn-sbctl list datapath-binding | grep "tunnel_key.*: "$d -B 1 | grep -q "logical-router"
    if [[ $? -eq 0 ]]; then
        echo "true"
    else
        echo "false"
    fi
}
function print_datapath_from_inport() {
    input_flow=`sudo ovs-ofctl dump-flows br-int table=0 | grep in_port=$1`
    mt=`get_mt_from_inport $1`
    r6=`get_r6_from_inport $1`
    echo "========================================================="
    nh_mac_flow=''
    if [[ `mt_belongs_to_router_datapath $mt` == "true" ]]; then
        echo "enter router datapath..."
        r7_flow=`sudo ovs-ofctl dump-flows br-int table=20 | grep "metadata=$mt,nw_dst=$dst_nw"`
        r7=`echo $r7_flow | cut -d ':' -f 10 | cut -d '-' -f 1`
        reg0=`echo $r7_flow | cut -d ':' -f 2 | cut -d '-' -f 1`
        if [[ $reg0 == "NXM_OF_IP_DST[]" ]]; then
            _a=`echo $dst_ip | cut -d '.' -f 1`
            _b=`echo $dst_ip | cut -d '.' -f 2`
            _c=`echo $dst_ip | cut -d '.' -f 3`
            _d=`echo $dst_ip | cut -d '.' -f 4`
            reg0=`printf "0x%x%02x%02x%02x" $_a $_b $_c $_d`
        fi
        nh_mac_flow=`sudo ovs-ofctl dump-flows br-int table=21 | grep "reg0=$reg0,reg7=$r7,metadata=$mt"`
        if [[ $nh_mac_flow == "" ]]; then
            sudo ovs-ofctl dump-flows br-int table=21 | grep "reg7=$r7,metadata=$mt"
            echo "fail to determine, exit..."
            exit 1
        fi
        nh_mac=`echo $nh_mac_flow | cut -d ':' -f 2-7 | cut -d ',' -f 1`
        echo "nexthop mac:" $nh_mac
    else
        echo "enter switch datapath..."
        r7_flow=`sudo ovs-ofctl dump-flows br-int table=26 | grep "metadata=$mt,dl_dst=$nh_mac"`
        if [[ $r7_flow == "" ]]; then
            sudo ovs-ofctl dump-flows br-int table=26 | grep "metadata=$mt"
            echo "fail to determine, exit..."
            exit 1
        fi
        r7=`echo $r7_flow | cut -d ':' -f 7 | cut -d '-' -f 1`
    fi
    output_flow=`sudo ovs-ofctl dump-flows br-int table=64 | grep "reg7=$r7,metadata=$mt"`
    outport=`echo $output_flow | cut -d ':' -f 2`
    echo $input_flow
    echo $r7_flow
    if [[ $nh_mac_flow != "" ]]; then
        echo $nh_mac_flow
    fi
    echo $output_flow
    next_datapath_from_outport $outport
}
function outport_end_check() {
    if [[ $1 -eq $dp_ofp ]]; then
        echo "enter the target port..."
        exit 0
    fi
    sudo ovs-ofctl show br-int | grep "$1(" | cut -d "(" -f 2 | grep -q "tap"
    if [[ $? -eq 0 ]]; then
        echo "failed with entering another tap device..."
        exit 1
    fi
}
function next_datapath_from_outport() {
    outport_end_check $1
    outport_name=`sudo ovs-ofctl show br-int | grep "$1(" | cut -d "(" -f 2 | cut -d ")" -f 1`
    inport_name=`sudo ovs-vsctl show | grep "Port \"$outport_name" -A 4 | grep options | cut -d '"' -f 2`
    inport=`get_ofport_from_name $inport_name`
    echo "leaving "$outport_name
    echo "will enter "$inport_name
    print_datapath_from_inport $inport
}

print_datapath_from_inport $sp_ofp
