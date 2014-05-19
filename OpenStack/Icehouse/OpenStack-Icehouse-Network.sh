#!/usr/bin/env bash

# Assume compute node has singe IP
# Plese confirm your /etc/hosts
# like this:
# controller  192.168.10.10
# network     192.168.10.11
# compute1    192.168.10.12

HOSTNAME=network
LOCALIP=192.168.10.11

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

sed -i "s/net.ipv4.ip_forward = 0/\
net.ipv4.ip_forward = 1/g" /etc/sysctl.conf
sed -i "s/net.ipv4.conf.default.rp_filter = 1/\
net.ipv4.conf.default.rp_filter = 0/g" /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/a\
net.ipv4.conf.all.rp_filter = 0" /etc/sysctl.conf

sysctl -p

yum install openstack-neutron openstack-neutron-ml2 \
  openstack-neutron-openvswitch

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

openstack-config --set /etc/neutron/l3_agent.ini DEFAULT \
  interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/l3_agent.ini DEFAULT \
  use_namespaces True

openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
  interface_driver neutron.agent.linux.interface.OVSInterfaceDriver
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
  dhcp_driver neutron.agent.linux.dhcp.Dnsmasq
openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
  use_namespaces True

openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  auth_url http://controller:5000/v2.0
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  auth_region regionOne
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  admin_tenant_name service
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  admin_user neutron
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  admin_password 123456
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  nova_metadata_ip controller
openstack-config --set /etc/neutron/metadata_agent.ini DEFAULT \
  metadata_proxy_shared_secret 123456

openstack-config --set /etc/nova/nova.conf DEFAULT \
  service_neutron_metadata_proxy true
openstack-config --set /etc/nova/nova.conf DEFAULT \
  neutron_metadata_proxy_shared_secret 123456

service openstack-nova-api restart

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
  type_drivers gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
  tenant_network_types gre
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2 \
  mechanism_drivers openvswitch
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ml2_type_gre \
  tunnel_id_ranges 1:1000
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini ovs \
  local_ip LOCALIP
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

ovs-vsctl add-br br-ex

ovs-vsctl add-port br-ex eth0
ethtool -K eth0 gro off

ln -s plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini

cp /etc/init.d/neutron-openvswitch-agent /etc/init.d/neutron-openvswitch-agent.orig
sed -i 's,plugins/openvswitch/ovs_neutron_plugin.ini,plugin.ini,g' /etc/init.d/neutron-openvswitch-agent

service neutron-openvswitch-agent start
service neutron-l3-agent start
service neutron-dhcp-agent start
service neutron-metadata-agent start
chkconfig neutron-openvswitch-agent on
chkconfig neutron-l3-agent on
chkconfig neutron-dhcp-agent on
chkconfig neutron-metadata-agent on