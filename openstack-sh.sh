#!/usr/bin/env bash

# Please configure your network (esp. IP address) first!!

# networking
service NetworkManager stop
service network start
chkconfig NetworkManager off
chkconfig network on

hostname controller

# ntp
yum -y install ntp
service ntpd start
chkconfig ntpd on

# mysql
yum install -y mysql mysql-server MySQL-python
sed '2 ibind-address = controller' -i /etc/my.cnf
service mysqld start
chkconfig mysqld on
mysql_install_db
mysql_secure_installation

# OpenStack packages
yum install -y http://repos.fedorapeople.org/repos/openstack/openstack-havana/rdo-release-havana-6.noarch.rpm
yum install -y http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
yum install -y openstack-utils
yum install -y openstack-selinux

# qpid
yum install -y qpid-cpp-server memcached
sed "s/auth=yes/auth=no/g" /etc/qpidd.conf
service qpidd start
chkconfig qpidd on

# Keystone-install
yum install -y openstack-keystone python-keystoneclient

openstack-config --set /etc/keystone/keystone.conf \
   sql connection mysql://root:123456@controller/keystone

openstack-db --init --service keystone --password 123456

openstack-config --set /etc/keystone/keystone.conf DEFAULT \
   admin_token 123456

keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/* /var/log/keystone/keystone.log

service openstack-keystone start
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

keystone service-create --name=keystone --type=identity \
  --description="Keystone Identity Service"

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
yum install -y openstack-glance

openstack-config --set /etc/glance/glance-api.conf \
   DEFAULT sql_connection mysql://root:123456@controller/glance
openstack-config --set /etc/glance/glance-registry.conf \
   DEFAULT sql_connection mysql://root:123456@controller/glance

openstack-db --init --service glance --password 123456

keystone user-create --name=glance --pass=123456 \
 --email=glance@example.com
keystone user-role-add --user=glance --tenant=service --role=admin

openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
 auth_uri http://controller:5000
openstack-config --set /etc/glance/glance-api.conf keystone_authtoken \
 auth_host controller
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
 admin_tenant_name service
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
 admin_user glance
openstack-config --set /etc/glance/glance-registry.conf keystone_authtoken \
 admin_password 123456
openstack-config --set /etc/glance/glance-registry.conf paste_deploy \
 flavor keystone

sed '/auth_token:filter_factory/a\
auth_host=controller\
admin_user=glance\
admin_tenant_name=service\
admin_password=123456' -i /usr/share/glance/glance-api-dist-paste.ini

sed '/auth_token:filter_factory/a\
auth_host=controller\
admin_user=glance\
admin_tenant_name=service\
admin_password=123456' -i /usr/share/glance/glance-registry-dist-paste.ini

cp /usr/share/glance/glance-api-dist-paste.ini /etc/glance/glance-api-paste.ini
cp /usr/share/glance/glance-registry-dist-paste.ini /etc/glance/glance-registry-paste.ini

keystone service-create --name=glance --type=image \
  --description="Glance Image Service"

keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ image / {print $2}') \
  --publicurl=http://controller:9292 \
  --internalurl=http://controller:9292 \
  --adminurl=http://controller:9292

service openstack-glance-api start
service openstack-glance-registry start
chkconfig openstack-glance-api on
chkconfig openstack-glance-registry on

# Nova-controller-install
yum install -y openstack-nova python-novaclient

openstack-config --set /etc/nova/nova.conf \
  database connection mysql://root:123456@controller/nova

openstack-config --set /etc/nova/nova.conf \
  DEFAULT rpc_backend nova.openstack.common.rpc.impl_qpid
openstack-config --set /etc/nova/nova.conf DEFAULT qpid_hostname controller

openstack-db --init --service nova --password 123456

openstack-config --set /etc/nova/nova.conf DEFAULT my_ip controller
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_listen controller
openstack-config --set /etc/nova/nova.conf DEFAULT vncserver_proxyclient_address controller

keystone user-create --name=nova --pass=123456 --email=nova@example.com
keystone user-role-add --user=nova --tenant=service --role=admin

openstack-config --set /etc/nova/nova.conf DEFAULT auth_strategy keystone
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_host controller
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_protocol http
openstack-config --set /etc/nova/nova.conf keystone_authtoken auth_port 35357
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_user nova
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_tenant_name service
openstack-config --set /etc/nova/nova.conf keystone_authtoken admin_password 123456

sed '/auth_token:filter_factory/a\
auth_host = controller\
auth_port = 35357\
auth_protocol = http\
auth_uri = http://controller:5000/v2.0\
admin_tenant_name = service\
admin_user = nova\
admin_password = 123456' -i /etc/nova/api-paste.ini

keystone service-create --name=nova --type=compute \
  --description="Nova Compute service"

keystone endpoint-create \
  --service-id=$(keystone service-list | awk '/ compute / {print $2}') \
  --publicurl=http://controller:8774/v2/%\(tenant_id\)s \
  --internalurl=http://controller:8774/v2/%\(tenant_id\)s \
  --adminurl=http://controller:8774/v2/%\(tenant_id\)s

service openstack-nova-api start
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

openstack-config --set /etc/nova/nova.conf DEFAULT libvirt_type qemu

service libvirtd start
service messagebus start
chkconfig libvirtd on
chkconfig messagebus on
service openstack-nova-compute start
chkconfig openstack-nova-compute on

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

sed -i 's/OPENSTACK_HOST = "127.0.0.1"/\
OPENSTACK_HOST = "controller"/g' /etc/openstack-dashboard/local_settings

setsebool httpd_can_network_connect on

service httpd start
service memcached start
chkconfig httpd on
chkconfig memcached on

# Cinder-install

yum -y install openstack-cinder

openstack-config --set /etc/cinder/cinder.conf \
  database connection mysql://root:123456@controller/cinder

keystone user-create --name=cinder --pass=123456 --email=cinder@example.com
keystone user-role-add --user=cinder --tenant=service --role=admin

