#!/usr/bin/env python2
# writen by zongkai@polex.com.cn

METHOD = {
    'create': 'POST',
    'delete': 'DELETE',
    'show': 'GET',
    'show_n': 'GET',
    'list': 'GET',
    'update': 'PUT',
}

URL = {
    "loadbalancer": ''
}

def get_token():
    if [[ $OS_TOKEN == "" ]]; then
        source ~/openrc
        openstack --version -q >/dev/null
        if [[ $? -ne 0 ]]; then
            echo "this node has no openstackclient install, exit."
        else
            OS_TOKEN=`openstack token issue | awk '/ id /{print $4}'`
        fi
    fi
def oceana_neutron_api():
    arg3=${3-\$3}
    arg4=${4-\$4}
    arg5=${5-\$5}
    curl="curl -g -i -X"
    token="-H \"X-Auth-Token: $OS_TOKEN\""
    case $1 in
        "loadbalancer")
            resource="v2.0/lbaas/loadbalancers"
            case $2 in
                "create")
                    ret="$curl POST http://$arg3:9696/${resource}.json $token -d '{\"loadbalancer\": {\"vip_subnet_id\": \"$arg4\", \"name\": \"$arg5\", \"admin_state_up\": true}}'"
                    ;;
                "show")
                    ret="$curl GET http://$arg3:9696/${resource}/${arg4}.json $token"
                    ;;
                "show_n")$
                    ret="$curl GET http://$arg3:9696/${resource}.json?fields=id\&name=${arg4} $token"
                    ;;
                "list")
                    ret="$curl GET http://$arg3:9696/${resource}.json $token"
                    ;;
                "update")
                    ret="not supported yet, please update .bashrc"
                    ;;
                "delete")
                    ret="curl -g -i -X DELETE http://$arg3:9696/v2.0/lbaas/loadbalancers/${arg4}.json $token"
                    ;;
                *)
                    ret="unknown action, please specify an action, like create, update, show(id), show_n(name), delete, list"
            esac
            ;;
        *)
            ret="unknown resource...please update .bashrc"
    esac
    echo $ret
    if [[ ${ret:0:4} == "curl" ]]; then
        echo "$ret" | sed 's/\$/\x01/g' | grep -aPq "\x01"
        if [[ $? -ne 0 ]]; then
            echo "tip: ${ret/-i /} | python -mjson.tool"
        else
            echo "you have necessary arguments not assigned"
        fi
    fi
}
