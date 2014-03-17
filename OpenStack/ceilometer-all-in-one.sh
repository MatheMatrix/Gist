#ceilometer install in controller node

#Test installatiom model works
function test()
{
if [[ $? -ne 0 ]]; then
echo "$1 cant start";
exit 0;
fi
}

yum -y install openstack-ceilometer-api openstack-ceilometer-collector openstack-ceilometer-central python-ceilometerclient
yum -y install mongodb-server mongodb
service mongod start
test mongo
chkconfig mongod on

mongo --host="localhost" ceilometer mongo.js
test mongo.js

openstack-config --set /etc/ceilometer/ceilometer.conf \
database connection mongodb://ceilometer:123456@localhost:27017/ceilometer

ADMIN_TOKEN=123456
openstack-config --set /etc/ceilometer/ceilometer.conf publisher_rpc metering_secret $ADMIN_TOKEN

source ~/keystonerc
keystone user-create --name=ceilometer --pass=123456 --email=ceilometer@example.com
keystone user-role-add --user=ceilometer --tenant=service --role=admin

openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken auth_host controller
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken admin_tenant_name service
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken auth_protocol http
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken admin_password 123456
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_tenant_name service
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_password 123456

keystone service-create --name=ceilometer --type=metering \
--description="Ceilometer Telemetry Service"

keystone endpoint-create \
--service-id=$(keystone service-list | awk '/ metering / {print $2}') \
--publicurl=http://controller:8777 \
--internalurl=http://controller:8777 \
--adminurl=http://controller:8777

service openstack-ceilometer-api start
service openstack-ceilometer-central start
service openstack-ceilometer-collector start
test ceilometer-controller
chkconfig openstack-ceilometer-api on
chkconfig openstack-ceilometer-central on
chkconfig openstack-ceilometer-collector on

#Add the Image Service agent for the Telemetry service
openstack-config --set /etc/glance/glance-api.conf DEFAULT notifier_strategy qpid
service openstack-glance-api restart
service openstack-glance-registry restart

#Add the Block Storage Service agent for the Telemetry service
openstack-config --set /etc/cinder/cinder.conf DEFAULT control_exchange cinder
openstack-config --set /etc/cinder/cinder.conf DEFAULT notification_driver cinder.openstack.common.notifier.rpc_notifier

service openstack-cinder-api restart
#service openstack-cinder-volume restart

#ceilometer install in compute node

yum -y install openstack-ceilometer-compute

openstack-config --set /etc/nova/nova.conf DEFAULT \
instance_usage_audit True
openstack-config --set /etc/nova/nova.conf DEFAULT \
instance_usage_audit_period hour
openstack-config --set /etc/nova/nova.conf DEFAULT \
notify_on_state_change vm_and_task_state

openstack-config --set /etc/nova/nova.conf DEFAULT \
notification_driver nova.openstack.common.notifier.rpc_notifier
sed -i '/notification_driver/a\
notification_driver = ceilometer.compute.nova_notifier' /etc/nova/nova.conf

openstack-config --set /etc/ceilometer/ceilometer.conf publisher_rpc metering_secret 123456

openstack-config --set /etc/ceilometer/ceilometer.conf DEFAULT qpid_hostname controller

source ~/keystonerc
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken auth_host controller
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken admin_user ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken admin_tenant_name service
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken auth_protocol http
openstack-config --set /etc/ceilometer/ceilometer.conf \
keystone_authtoken admin_password 123456
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_username ceilometer
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_tenant_name service
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_password 123456
openstack-config --set /etc/ceilometer/ceilometer.conf \
service_credentials os_auth_url http://controller:5000/v2.0

service openstack-ceilometer-compute start
test ceilometer-compute
chkconfig openstack-ceilometer-compute on

