#!/bin/bash
# writen by zongkai@polex.com.cn

path="$(cd `dirname $0`; pwd)"
function insert
{
    data=$2
    key=`echo $data | cut -d ' ' -f 1`
    key_end=""
    if [[ $key == "alias" ]]; then
        key_end="="
    fi
    cur_line=`grep -n "^$key ${1}${key_end}" ~/.bashrc | cut -d ':' -f 1`
    if [[ $cur_line == "" ]]; then
        echo $data >> ~/.bashrc
        echo "inserted $1..."
    else
        cur_line=`grep -n "^$data" ~/.bashrc | cut -d ':' -f 1`
        if [[ $cur_line == "" ]]; then
            sed -i "/^$key ${1}${key_end}.*$/d" ~/.bashrc
            echo $data >> ~/.bashrc
            echo "updated $1..."
        else
            echo "nothing to do for $1..."
        fi
    fi
}
insert "oceana" "alias oceana='python $path/oceana.py'"
insert "oceana_update" "alias oceana_update='cd $path && git pull && cd - >> /dev/null'"
insert "oceana_set_os_token" "function oceana_set_os_token { source ~/openrc;  token=\`openstack token issue | awk '/ id /{print \$4}'\`; export OCEANA_OS_TOKEN=\$token; }"
insert "oceana_set_os_api_ip" "function oceana_set_os_api_ip { if [[ \$1 != \"\" ]]; then export OCEANA_OS_API_IP=\$1; else echo \"Need assign an IP\"; fi }"
echo 'alias oceana updated. run `source ~/.bashrc` to go.'
