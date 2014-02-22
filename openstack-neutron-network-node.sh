#!/usr/bin/env bash

# Notice Line 72

yum -y install openstack-neutron

for s in neutron-{dhcp,metadata,l3}-agent; do chkconfig $s on; done;

sed -i "s/net.ipv4.ip_forward=0/\
net.ipv4.ip_forward=1/g" /etc/sysctl.conf
sed -i "s/net.ipv4.conf.default.rp_filter=1/\
net.ipv4.conf.default.rp_filter=0/g" /etc/sysctl.conf
sed -i "/net.ipv4.conf.default.rp_filter/a\
net.ipv4.conf.default.rp_filter=0" /etc/sysctl.conf

service network restart

openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 auth_port 35357
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 auth_protocol http
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 admin_tenant_name service
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 admin_user neutron
openstack-config --set /etc/neutron/neutron.conf keystone_authtoken \
 admin_password 123456

openstack-config --set /etc/neutron/neutron.conf agent \
   root_helper sudo "neutron-rootwrap /etc/neutron/rootwrap.conf"

openstack-config --set /etc/neutron/neutron.conf DEFAULT \
 rpc_backend neutron.openstack.common.rpc.impl_qpid
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
 qpid_hostname controller

 openstack-config --set /etc/neutron/neutron.conf DATABASE sql_connection \
   mysql://neutron:123456@controller/neutron

openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 paste.filter_factory keystoneclient.middleware.auth_token:filter_factory
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 auth_host controller
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 auth_uri http://controller:5000
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 admin_tenant_name service
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 admin_user neutron
openstack-config --set /etc/neutron/api-paste.ini filter:authtoken \
 admin_password 123456

## Open vSwitch-install (INSERTED!!) ##

yum nstall -y iopenstack-neutron-openvswitch

service openvswitch start

chkconfig openvswitch on

ovs-vsctl add-br br-int
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex

echo "
DEVICE=br-ex
DEVICETYPE=ovs
TYPE=OVSBridge
BOOTPROTO=static
IPADDR=172.16.1.73
NETMASK=255.255.0.0
GATEWAY=172.16.0.254
ONBOOT=yes" > /etc/sysconfig/network-scripts/ifcfg-br-ex

MAC=$(cat /etc/sysconfig/network-scripts/ifcfg-eth0|grep HWADDR)
cp /etc/sysconfig/network-scripts/ifcfg-eth0 /etc/sysconfig/network-scripts/ifcfg-eth0.bak

echo "
DEVICE=eth0
ONBOOT=yes
$MAC
TYPE=OVSPort
DEVICETYPE=ovs
OVS_BRIDGE=br-ex" > /etc/sysconfig/network-scripts/ifcfg-eth0ls

service network restart

sed '/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/a\
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver\
use_namespaces = True' -i  /etc/neutron/l3_agent.ini

sed "/ovs_use_veth =/a\
ovs_use_veth = True" -i /etc/neutron/l3_agent.ini

sed '/interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver/a\
interface_driver = neutron.agent.linux.interface.OVSInterfaceDriver\
use_namespaces = True' -i  /etc/neutron/dhcp_agent.ini

sed "/ovs_use_veth =/a\
ovs_use_veth = True" -i /etc/neutron/dhcp_agent.ini

sed "/core_plugin =/a\
core_plugin = neutron.plugins.openvswitch.ovs_neutron_plugin.OVSNeutronPluginV2" \
-i  /etc/neutron/neutron.conf

## GRE tunneling (INSERTED!!) ##

ovs-vsctl add-br br-tun

sed -i '/# Example: tenant_network_type = vxlan/a\
tenant_network_type = gre\
tunnel_id_ranges = 1:1000\
enable_tunneling = True\
integration_bridge = br-int\
tunnel_bridge = br-tun\
local_ip = 192.168.10.10' /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

## GRE tunneling (END) ##

sed -i "/firewall_driver = neutron.agent.linux.iptables/a\
firewall_driver = neutron.agent.firewall.NoopFirewallDriver" \
/etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini

chkconfig neutron-openvswitch-agent on

## Open vSwitch-install (END) ##

openstack-config --set /etc/neutron/dhcp_agent.ini DEFAULT \
   dhcp_driver neutron.agent.linux.dhcp.Dnsmasq

openstack-config --set /etc/nova/nova.conf DEFAULT \
  neutron_metadata_proxy_shared_secret 123456
openstack-config --set /etc/nova/nova.conf DEFAULT \
  service_neutron_metadata_proxy true

service openstack-nova-api restart

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

ln -s /etc/neutron/plugins/openvswitch/ovs_neutron_plugin.ini /etc/neutron/plugin.ini

service neutron-dhcp-agent restart
service neutron-l3-agent restart
service neutron-metadata-agent restart

service neutron-openvswitch-agent restart