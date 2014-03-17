#!/usr/bin/env bash

# networking
service NetworkManager stop
service network start
chkconfig NetworkManager off
chkconfig network on

# ntp
yum -y install ntp
service ntpd start
chkconfig ntpd on


# mysql
yum install -y mysql MySQL-python

# OpenStack packages
yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-havana/rdo-release-havana-6.noarch.rpm
yum install -y http://dl.fedoraproject.org/pub/epel/5/x86_64/epel-release-5-4.noarch.rpm
yum install -y openstack-utils
yum install -y openstack-selinux
yum install -y openstack-cinder

# make keystonerc
echo "export OS_USERNAME=admin
export OS_PASSWORD=123456
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://controller:35357/v2.0" > ~/keystonerc

# 创建逻辑卷组
dd if=/dev/zero of=/opt/cinder-volumes.img bs=1M seek=100000 count=0
losetup -f /opt/cinder-volumes.img
losetup -a
vgcreate cinder-volumes /dev/loop0

sed '/auth_token:filter_factory/a\
auth_host = controller\
auth_port = 35357\
auth_protocol = http\
admin_tenant_name = service\
admin_user = cinder\
admin_password = 123456' -i /etc/cinder/api-paste.ini

openstack-config --set /etc/cinder/cinder.conf \
  DEFAULT rpc_backend cinder.openstack.common.rpc.impl_qpid
openstack-config --set /etc/cinder/cinder.conf \
  DEFAULT qpid_hostname controller

openstack-config --set /etc/cinder/cinder.conf \
  database connection mysql://cinder:123456@controller/cinder

sed -i '1 i\include /etc/cinder/volumes/*' /etc/tgt/targets.conf

service openstack-cinder-volume start
service tgtd start
chkconfig openstack-cinder-volume on
chkconfig tgtd on

