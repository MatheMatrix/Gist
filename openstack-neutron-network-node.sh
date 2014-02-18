keystone user-create --name=neutron --pass=NEUTRON_PASS --email=neutron@example.com

keystone user-role-add --user=neutron --tenant=service --role=admin

keystone service-create --name=neutron --type=network \
     --description="OpenStack Networking Service"

keystone endpoint-create \
     --service-id $(keystone service-list | awk '/ network / {print $2}') \
     --publicurl http://controller:9696 \
     --adminurl http://controller:9696 \
     --internalurl http://controller:9696

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

openstack-config --set /etc/neutron/neutron.conf AGENT \
   root_helper sudo neutron-rootwrap /etc/neutron/rootwrap.conf

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

## Open vSwitch-install (INSERTED!!) PART OF Neutron-network-node ##

yum -y install openstack-neutron-openvswitch

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
