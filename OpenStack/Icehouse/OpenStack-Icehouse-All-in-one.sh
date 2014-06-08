#!/usr/bin/env bash

# Please configure your network (esp. IP address) first!!

# Mysql installation will need root's current password (press enter directly)
# and please set root password and make it '123456'!!

# If updated kernel, please reboot first

HOSTNAME=controller

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

yum install kernel iproute

# ntp

yum install -y ntp
service ntpd start
chkconfig ntpd on

cp /etc/localtime /etc/localtime.bak
cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime

# mysql

yum install -y mysql mysql-server MySQL-python
sed '2 ibind-address = controller' -i /etc/my.cnf
sed "/bind-address = controller/a\\
default-storage-engine = innodb\\
collation-server = utf8_general_ci\\
init-connect = 'SET NAMES utf8'\\
character-set-server = utf8" -i test.cnf
service mysqld start
test mysql
chkconfig mysqld on
mysql_install_db
mysql_secure_installation

# Please DELETE the anonymous users of db!

iptables -I INPUT 4 -p tcp -m state --state NEW -m tcp --dport 3306 -j ACCEPT
service iptables save

# OpenStack packages

yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/rdo-release-icehouse-3.noarch.rpm
yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y openstack-utils
yum install -y openstack-selinux

yum upgrade

# If the upgrade included a new kernel package, reboot the system to ensure the new kernel is running.

# qpid

yum install -y qpid-cpp-server
sed "s/auth=yes/auth=no/g" -i /etc/qpidd.conf
service qpidd start
test qpid
chkconfig qpidd on

# Keystone-install

yum install -y openstack-keystone python-keystoneclient

openstack-config --set /etc/keystone/keystone.conf \
   sql connection mysql://root:123456@controller/keystone

mysql -u root -p123456 -e"CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'controller'
IDENTIFIED BY '123456';"

su -s /bin/sh -c "keystone-manage db_sync" keystone

openstack-config --set /etc/keystone/keystone.conf DEFAULT \
   admin_token 123456

keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/* /var/log/keystone/keystone.log
chmod -R o-rwx /etc/keystone/ssl

(crontab -l 2>&1 | grep -q token_flush) || \
echo '@hourly /usr/bin/keystone-manage token_flush >/var/log/keystone/keystone-tokenflush.log 2>&1' >> /var/spool/cron/root

service openstack-keystone start
test keystone
chkconfig openstack-keystone on

# Keystone-define

export OS_SERVICE_TOKEN=123456
export OS_SERVICE_ENDPOINT=http://controller:35357/v2.0

keystone tenant-create --name=admin --description="Admin Tenant"
keystone tenant-create --name=service --description="Service Tenant"

keystone user-create --name=admin --pass=123456 \
   --email=admin@example.com
keystone role-create --name=admin
keystone user-role-add --user=admin --tenant=admin --role=admin
keystone user-role-add --user=admin --tenant=admin --role=_member_

keystone user-create --name=demo --pass=123456 --email=demo@example.com
keystone tenant-create --name=demo --description="Demo Tenant"
keystone user-role-add --user=demo --role=_member_ --tenant=demo

keystone service-create --name=keystone --type=identity \
  --description="OpenStack Identity"

keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ identity / {print $2}') \
  --publicurl=http://controller:5000/v2.0 \
  --internalurl=http://controller:5000/v2.0 \
  --adminurl=http://controller:35357/v2.0

# make keystonerc

echo "export OS_USERNAME=admin
export OS_PASSWORD=123456
export OS_TENANT_NAME=admin
export OS_AUTH_URL=http://controller:35357/v2.0" > ~/keystonerc

# Glance-install

yum install -y openstack-glance python-glanceclient

openstack-config --set /etc/glance/glance-api.conf database \
  connection mysql://glance:GLANCE_DBPASS@controller/glance
openstack-config --set /etc/glance/glance-registry.conf database \
  connection mysql://glance:GLANCE_DBPASS@controller/glance

openstack-config --set /etc/glance/glance-api.conf DEFAULT \
  rpc_backend qpid
openstack-config --set /etc/glance/glance-api.conf DEFAULT \
  qpid_hostname controller

mysql -u root -p123456 -e"CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'controller'
IDENTIFIED BY '123456';"

su -s /bin/sh -c "glance-manage db_sync" glance

keystone user-create --name=glance --pass=123456 \
 --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin

openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  auth_uri http://controller:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  auth_host controller
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  auth_port 35357
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  auth_protocol http
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  admin_tenant_name service
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  admin_user glance
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
  admin_password 123456
openstack-config --set /etc/glance/glance-api.conf paste_deploy \
  flavor keystone
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  auth_uri http://controller:5000
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  auth_host controller
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  auth_port 35357
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  auth_protocol http
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
  admin_password 123456
openstack-config --set /etc/glance/glance-registry.conf paste_deploy \
  flavor keystone

keystone service-create --name=glance --type=image \
  --description="OpenStack Image Service"

keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ image / {print $2}') \
  --publicurl=http://controller:9292 \
  --internalurl=http://controller:9292 \
  --adminurl=http://controller:9292

service openstack-glance-api start
service openstack-glance-registry start
test glance
chkconfig openstack-glance-api on
chkconfig openstack-glance-registry on

# Nova-controller-install

yum install -y openstack-nova-api openstack-nova-cert openstack-nova-conductor \
  openstack-nova-console openstack-nova-novncproxy openstack-nova-scheduler \
  python-novaclient

openstack-config --set /etc/nova/nova.conf \
  database connection mysql://root:123456@controller/nova

openstack-config --set /etc/nova/nova.conf \
  DEFAULT rpc_backend nova.openstack.common.rpc.impl_qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname controller

mysql -u root -p123456 -e"CREATE DATABASE nova;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'controller'
IDENTIFIED BY '123456';"

su -s /bin/sh -c "nova-manage db sync" nova

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip controller
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen controller
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address controller

keystone user-create --name=nova --pass=123456 --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin

openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_uri http://controller:5000
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password 123456

keystone service-create --name=nova --type=compute \
  --description="Nova Compute service"

keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ compute / {print $2}') \
  --publicurl=http://controller:8774/v2/%\(tenant_id\)s \
  --internalurl=http://controller:8774/v2/%\(tenant_id\)s \
  --adminurl=http://controller:8774/v2/%\(tenant_id\)s

service openstack-nova-api start
test nova-api
service openstack-nova-cert start
service openstack-nova-consoleauth start
service openstack-nova-scheduler start
service openstack-nova-conductor start
service openstack-nova-novncproxy start
chkconfig openstack-nova-api on
chkconfig openstack-nova-cert on
chkconfig openstack-nova-consoleauth on
chkconfig openstack-nova-scheduler on
chkconfig openstack-nova-conductor on
chkconfig openstack-nova-novncproxy on

# Nova-compute-install

yum install -y openstack-nova-compute

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

# Neutron-controller-install

mysql -u root -p123456 -e"CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%'
IDENTIFIED BY '123456';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'controller'
IDENTIFIED BY '123456';"

keystone user-create --name=neutron --pass=123456 --email=neutron@example.com

keystone user-role-add --user=neutron --tenant=service --role=admin

keystone service-create --name=neutron --type=network \
     --description="OpenStack Networking Service"

keystone endpoint-create \
     --service-id $(keystone service-list | awk '/ network / {print $2}') \
     --publicurl http://controller:9696 \
     --adminurl http://controller:9696 \
     --internalurl http://controller:9696

yum install -y openstack-neutron openstack-neutron-ml2 \
  python-neutronclient openstack-neutron-openvswitch

openstack-config --set /etc/neutron/neutron.conf database connection \
   mysql://neutron:123456@controller/neutron

openstack-config --set /etc/neutron/neutron.conf DEFAULT auth_strategy keystone

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
  notify_nova_on_port_status_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  notify_nova_on_port_data_changes True
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  nova_url http://controller:8774/v2
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  nova_admin_username nova
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  nova_admin_tenant_id $(keystone tenant-list | awk '/ service / { print $2 }')
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  nova_admin_password 123456
openstack-config --set /etc/neutron/neutron.conf DEFAULT \
  nova_admin_auth_url http://controller:35357/v2.0

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
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
  firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
  enable_security_group True

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

service openstack-nova-api restart
service openstack-nova-scheduler restart
service openstack-nova-conductor restart

service neutron-server start
test Neutron
chkconfig neutron-server on

# Neutron-network-install

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

openstack-config --set /etc/nova/nova.conf DEFAULT \
  service_neutron_metadata_proxy true
openstack-config --set /etc/nova/nova.conf DEFAULT \
  neutron_metadata_proxy_shared_secret 123456

service openstack-nova-api restart

openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
  firewall_driver neutron.agent.linux.iptables_firewall.OVSHybridIptablesFirewallDriver
openstack-config --set /etc/neutron/plugins/ml2/ml2_conf.ini securitygroup \
  enable_security_group True

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

# Horizon-install

yum install -y memcached python-memcached mod_wsgi openstack-dashboard

sed -i "/^CACHES = {/{N;N;N;N;s/.*/\
CACHES = {\
   'default': {\
       'BACKEND' : 'django.core.cache.backends.memcached.MemcachedCache',\
       'LOCATION' : '127.0.0.1:11211',\
   }\
}/}" /etc/openstack-dashboard/local_settings

sed -i "s/ALLOWED_HOSTS = \['horizon.example.com', 'localhost'\]/\
ALLOWED_HOSTS = ['localhost', 'my-desktop', 'controller']/g" /etc/openstack-dashboard/local_settings

# Edit /etc/openstack-dashboard/local_settings and change OPENSTACK_HOST to the hostname of your Identity Service:
# OPENSTACK_HOST = "controller"

sed -i 's/OPENSTACK_KEYSTONE_DEFAULT_ROLE = "Member"/\
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "admin"/g' /etc/openstack-dashboard/local_settings

sed -i 's/SELINUX=enforcing/\
SELINUX=disabled/g' /etc/selinux/config

iptables -I INPUT -p tcp --dport 80 -j ACCEPT
service iptables save

setsebool httpd_can_network_connect on
setenforce 0

service httpd start
test httpd
service memcached start
chkconfig httpd on
chkconfig memcached on