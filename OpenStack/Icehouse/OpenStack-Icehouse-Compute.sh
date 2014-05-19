#!/usr/bin/env bash

# Assume compute node has singe IP
# Plese confirm your /etc/hosts
# like this:
# controller  192.168.10.10
# network     192.168.10.11
# compute1    192.168.10.12

HOSTNAME=compute1
LOCALIP=192.168.10.12

# Test installatiom model works
function test()
{
  if [[ $? -ne 0 ]]; then
    echo "$1 cant start";
    exit 0;
  fi
}

# networking

service NetworkManager stop
service network start
chkconfig NetworkManager off
chkconfig network on

hostname $HOSTNAME
sed -i "s/^HOSTNAME=.*/HOSTNAME=$HOSTNAME/g" /etc/sysconfig/network

# ntp
yum -y install ntp
service ntpd start
chkconfig ntpd on

cp /etc/localtime /etc/localtime.bak
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# mysql
yum install -y MySQL-python

# OpenStack packages
yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm
yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y openstack-utils
yum install -y openstack-selinux

yum upgrade

# If the upgrade included a new kernel package, reboot the system to ensure the new kernel is running.

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
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password 123456

openstack-config --set /etc/nova/nova.conf \
  DEFAULT rpc_backend qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname controller

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip compute1
openstack-config --set /etc/nova/nova.conf DEFAULT vnc_enabled True
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen 0.0.0.0
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address compute1
openstack-config --set /etc/nova/nova.conf \
  DEFAULT novncproxy_base_url http://controller:6080/vnc_auto.html

openstack-config --set /etc/nova/nova.conf DEFAULT glance_host controller

# openstack-config --set /etc/nova/nova.conf libvirt virt_type qemu

service libvirtd start
service messagebus start
chkconfig libvirtd on
chkconfig messagebus on
service openstack-nova-compute start
chkconfig openstack-nova-compute on

# Neutron-compute-install

sed -i "s/net.ipv4.conf.default.rp_filter = 1/\
net.ipv4.conf.default.rp_filter = 0/g" /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/a\
net.ipv4.conf.all.rp_filter = 0" /etc/sysctl.conf

sysctl -p

yum install -y openstack-neutron-ml2 openstack-neutron-openvswitch

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  auth_strategy keystone
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
  auth_uri http://controller:5000
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
  auth_host controller
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
  auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
  auth_port 35357
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

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  core_plugin ml2
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  service_plugins router

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
  type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
  tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
  mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre \
  tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs \
  local_ip $LOCALIP
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs \
  tunnel_type gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs \
  enable_tunneling True
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
  firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
  enable_security_group True

service openvswitch start
chkconfig openvswitch on

ovs-vsctl add-br br-int

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

ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent

service openstack-nova-compute restart

service neutron-openvswitch-agent start
chkconfig neutron-openvswitch-agent on