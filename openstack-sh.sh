#!/usr/bin/env bash

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
sed '2 ibind-address = 127.0.0.1' -i /etc/my.cnf
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
   sql connection mysql://root:123456@localhost/keystone

openstack-db --init --service keystone --password 123456

openstack-config --set /etc/keystone/keystone.conf DEFAULT \
   admin_token 123456

keystone-manage pki_setup --keystone-user keystone --keystone-group keystone
chown -R keystone:keystone /etc/keystone/* /var/log/keystone/keystone.log

service openstack-keystone start
chkconfig openstack-keystone on

# Keystone-define
export OS_SERVICE_TOKEN=123456
export OS_SERVICE_ENDPOINT=http://localhost:35357/v2.0

keystone tenant-create --name=admin --description="Admin Tenant"
keystone tenant-create --name=service --description="Service Tenant"

keystone user-create --name=admin --pass=123456 \
   --email=admin@example.com

keystone role-create --name=admin

keystone user-role-add --user=admin --tenant=admin --role=admin

keystone user-role-add --user=admin --tenant=admin --role=_member_