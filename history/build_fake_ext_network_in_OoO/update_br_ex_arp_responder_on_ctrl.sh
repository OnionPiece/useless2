#!/bin/bash
# writen by zongkai@polex.com.cn

function usage
{
    echo "usage: bash $0 IP MAC"
    exit 1
}

if [[ $# -ne 2 ]]; then
    usage
elif [[ `ipcalc -c $1 >> /dev/null` -ne 0 ]]; then
    usage
elif [[ `echo $2 | egrep "^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$"` == "" ]]; then
    usage
fi

bridge=br-ex
table=16
priority=1
path="$(cd `dirname $0`; pwd)"
bash ${path%/*}/mock_tools/build_arp_responder.sh $1 $2 $bridge $table $priority
