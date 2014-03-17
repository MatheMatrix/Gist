#install heat on the controller


#source rc file
if [ ! -f ~/keystonerc ]; then
	echo "export OS_USERNAME=admin" >> ~/keystonerc
	echo "export OS_PASSWORD=123456" >> ~/keystonerc
	echo "export OS_TENANT_NAME=admin" >> ~/keystonerc
	echo "export OS_AUTH_URL=http://controller:35357/v2.0" >> ~/keystonerc
fi
source ~/keystonerc


#set variables
read -s -p "Please input the database password for HEAT: " HEAT_DBPASS
echo
read -s -p "Please input the database password for ROOT:  " ROOT_DBPASS
echo
read -s -p "Please input the password for HEAT:  " HEAT_PASS
echo


#install heat
yum install openstack-heat-api openstack-heat-engine openstack-heat-api-cfn

openstack-config --set /etc/heat/heat.conf DEFAULT sql_connection mysql://heat:$HEAT_DBPASS@controller/heat

mysql --user=root --password=$ROOT_DBPASS -e \
"CREATE DATABASE heat;\
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'localhost' \
IDENTIFIED BY '"$HEAT_DBPASS"';
GRANT ALL PRIVILEGES ON heat.* TO 'heat'@'%' \
IDENTIFIED BY '"$HEAT_DBPASS"';"

heat-manage db_sync

keystone user-create --name=heat --pass=$HEAT_PASS
keystone user-role-add --user=heat --tenant=service --role=admin

sed -i "s/\[keystone_authtoken\]/\n\
\[keystone_authtoken\]\n\
auth_host = controller\n\
auth_port = 35357\n\
auth_protocol = http\n\
auth_uri = http:\/\/controller:5000\/v2.0\n\
admin_tenant_name = service\n\
admin_user = heat\n\
admin_password = $HEAT_PASS\n\
\[ec2_authtoken\]\n\
auth_uri = http:\/\/controller:5000\/v2.0\n\
keystone_ec2_uri = http:\/\/controller:5000\/v2.0\/ec2tokens\/\n/" /etc/heat/heat.conf

SERVICE_ID=`keystone service-create --name=heat --type=orchestration --description="Heat Orchestration API"`

SERVICE_ID=${SERVICE_ID#*\|*\|*\|*\|*\|*\|*\|*\|}
SERVICE_ID=${SERVICE_ID%%|*}
SERVICE_ID=`echo $SERVICE_ID`
keystone endpoint-create \
  --service-id=$SERVICE_ID \
  --publicurl=http://controller:8004/v1/%\(tenant_id\)s \
  --internalurl=http://controller:8004/v1/%\(tenant_id\)s \
  --adminurl=http://controller:8004/v1/%\(tenant_id\)s


SERVICE_ID=`keystone service-create --name=heat-cfn --type=cloudformation --description="Heat CloudFormation API"`

SERVICE_ID=${SERVICE_ID#*\|*\|*\|*\|*\|*\|*\|*\|}
SERVICE_ID=${SERVICE_ID%%|*}
SERVICE_ID=`echo $SERVICE_ID`
keystone endpoint-create \
  --service-id=$SERVICE_ID \
  --publicurl=http://controller:8000/v1 \
  --internalurl=http://controller:8000/v1 \
  --adminurl=http://controller:8000/v1


service openstack-heat-api start
service openstack-heat-api-cfn start
service openstack-heat-engine start
chkconfig openstack-heat-api on
chkconfig openstack-heat-api-cfn on
chkconfig openstack-heat-engine on
