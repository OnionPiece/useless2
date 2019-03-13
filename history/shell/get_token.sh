# writen by zongkai@polex.com.cn

if [[ $OCEANA_OS_TOKEN == "" ]]; then
    openstack --version -q
    if [[ $? -ne 0 ]]; then
        echo "this node has no openstackclient install"
    else
        source ~/openrc
        TOKEN=`openstack token issue | awk '/ id /{print $4}'`
        export OCEANA_OS_TOKEN=$TOKEN
    fi
fi
