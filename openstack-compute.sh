#!/usr/bin/env bash

# Notice GRE tunning's local ip setting, see line 119

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

cp /etc/localtime /etc/localtime.bak
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

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

source ~/keystonerc

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

openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_type kvm

service libvirtd start
service messagebus start
chkconfig libvirtd on
chkconfig messagebus on
service openstack-nova-compute start
chkconfig openstack-nova-compute on

sed -i "s/net.ipv4.ip_forward = 0/\
net.ipv4.ip_forward = 1/g" /etc/sysctl.conf
sed -i "s/net.ipv4.conf.default.rp_filter = 1/\
net.ipv4.conf.default.rp_filter = 0/g" /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/a\
net.ipv4.conf.all.rp_filter = 0" /etc/sysctl.conf

service network restart

## Neutron plug-in install (INSERTED!!) ##

yum install -y openstack-neutron-openvswitch

service openvswitch start
chkconfig openvswitch on

ovs-vsctl add-br br-int
ovs-vsctl add-br br-tun

sed -i "/core_plugin =/a\
core_plugin = neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2" /etc/neutron/neutron.conf

sed -i "/api_paste_config =/a\
api_paste_config = \/etc\/neutron\/api-paste.ini" /etc/neutron/neutron.conf

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
 rpc_backend neutron.openstack.common.rpc.impl_qpid

openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 auth_uri http://controller:5000

## GRE tunneling (INSERTED!!) ##

sed -i '/# Example: tenant_network_type = vxlan/a\
tenant_network_type = gre\
tunnel_id_ranges = 1:1000\
enable_tunneling = True\
integration_bridge = br-int\
tunnel_bridge = br-tun\
local_ip = 192.168.10.11' /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

## GRE tunneling (END) ##

sed -i "/firewall_driver = neutron.agent.linux.iptables/a\
firewall_driver = neutron.agent.firewall.NoopFirewallDriver" \
/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

chkconfig neutron-openvswitch-agent on

## Neutron plug-in install (END) ##

openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 auth_host controller
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 auth_url http://controller:35357/v2.0
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 admin_password 123456

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
 rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
 qpid_hostname controller

openstack-config --set /etc/neutron/neutron.conf agent \
   root_helper sudo "neutron-rootwrap /etc/neutron/rootwrap.conf"

openstack-config --set /etc/neutron/neutron.conf DATABASE sql_connection \
   mysql://neutron:123456@controller/neutron

openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 paste.filter_factory keystoneclient.middleware.auth_token:filter_factory
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 auth_host controller
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 admin_tenant_name service
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 admin_user neutron
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 admin_password 123456

openstack-config --set /etc/nova/nova.conf DEFAULT \
 network_api_class nova.network.neutronv2.api.API
openstack-config --set /etc/nova/nova.conf DEFAULT \
 neutron_url http://controller:9696
openstack-config --set /etc/nova/nova.conf DEFAULT \
 neutron_auth_strategy keystone
openstack-config --set /etc/nova/nova.conf DEFAULT \
 neutron_admin_tenant_name service
openstack-config --set /etc/nova/nova.conf DEFAULT \
 neutron_admin_username neutron
openstack-config --set /etc/nova/nova.conf DEFAULT \
 neutron_admin_password 123456
openstack-config --set /etc/nova/nova.conf DEFAULT \
 neutron_admin_auth_url http://controller:35357/v2.0
openstack-config --set /etc/nova/nova.conf DEFAULT \
 linuxnet_interface_driver nova.network.linux_net.LinuxOVSInterfaceDriver
openstack-config --set /etc/nova/nova.conf DEFAULT \
 firewall_driver nova.virt.firewall.NoopFirewallDriver
openstack-config --set /etc/nova/nova.conf DEFAULT \
 security_group_api neutron

sed -i 's/Defaults   !visiblepw/\
Defaults   visiblepw/g' /etc/sudoers

sed -i '/## Allow root to run any commands anywhere/a\
neutron    ALL=(ALL)    NOPASSWD: ALL' /etc/sudoers

sed -i "s/security_group_api = neutron/\
# security_group_api = neutron/" /etc/nova/nova.conf

service openstack-nova-compute restart

service neutron-openvswitch-agent restart