#!/usr/bin/env bash

# networking
service NetworkManager stop
service network start
chkconfig NetworkManager off
chkconfig network on

hostname compute1

# ntp
yum -y install ntp
service ntpd start
chkconfig ntpd on

# mysql
yum install -y mysql MySQL-python

# OpenStack packages
yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-havana/rdo-release-havana-6.noarch.rpm
yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y openstack-utils
yum install -y openstack-selinux

# make keystonerc
echo "export OS_USERNAME=admin
export OS_PASSWORD=123456
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://controller:35357/v2.0" > ~/keystonerc

# Nova-compute-install
yum install -y openstack-nova-compute

openstack-config --set /etc/nova/nova.conf database connection mysql://nova:123456@controller/nova
openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password 123456

openstack-config --set /etc/nova/nova.conf \
  DEFAULT rpc_backend nova.openstack.common.rpc.impl_qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname controller

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip compute1 
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address compute1
openstack-config --set /etc/nova/nova.conf \
  DEFAULT novncproxy_base_url http://controller:6080/vnc_auto.html

openstack-config --set /etc/nova/nova.conf DEFAULT glance_host controller

sed '/auth_token:filter_factory/a\
auth_host = controller\
auth_port = 35357\
auth_protocol = http\
auth_uri = http://controller:5000/v2.0\
admin_tenant_name = service\
admin_user = nova\
admin_password = 123456' -i /etc/nova/api-paste.ini

service libvirtd start
service messagebus start
chkconfig libvirtd on
chkconfig messagebus on
service openstack-nova-compute start
chkconfig openstack-nova-compute on