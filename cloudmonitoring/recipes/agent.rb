#
# Cookbook Name:: cloud_monitoring
# Recipe:: default
#
# Copyright 2012, Rackspace
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


cookbook_file "/var/chef/cache/get_entity.py" do
  source "get_entity.py"
  owner "root"
  group "root"
  mode "0755"
  action :create
end

#Get the entity for this server based on IP address and set the agent_id to the hostname
execute "get_entity" do
  command "python /var/chef/cache/get_entity.py -u #{node['cloud_monitoring']['rackspace_username']} -a #{node['cloud_monitoring']['rackspace_api_key']} -r #{node['cloud_monitoring']['rackspace_auth_region']} -i #{node.ipaddress} -o #{node['cloud_monitoring']['agent']['id']}"      
  user "root"
end

##Install Agent
package "rackspace-monitoring-agent" do
  action :upgrade
  notifies :restart, "service[rackspace-monitoring-agent]"
end

cookbook_file "/var/chef/cache/create_agent_token.py" do
  source "create_agent_token.py"
  owner "root"
  group "root"
  mode "0755"
  action :create
end

#Place Agent config file 
template "/etc/rackspace-monitoring-agent.cfg" do
  source "rackspace-monitoring-agent.erb"
  owner "root"
  group "root"
  mode 0600
  variables(
    :monitoring_id => node['cloud_monitoring']['agent']['id'],
    :monitoring_token => node['cloud_monitoring']['agent']['token']
  )
end

#Create an agent token and place it in the config file
execute "create_token" do
  command "TOKEN=`python /var/chef/cache/create_agent_token.py -u #{node['cloud_monitoring']['rackspace_username']} -a #{node['cloud_monitoring']['rackspace_api_key']} -r #{node['cloud_monitoring']['rackspace_auth_region']}` && sed -i \"s/monitoring_token ChangeMe/monitoring_token $TOKEN/g\" /etc/rackspace-monitoring-agent.cfg"      
  user "root"
end

#Set to start on boot
service "rackspace-monitoring-agent" do
  case node["platform"]
  when "centos","redhat","fedora"
    supports :restart => true, :status => true
  when "debian","ubuntu"
    supports :restart => true, :reload => true, :status => true
  end
  action [:enable, :start]
  action [:restart]  
end

cookbook_file "/var/chef/cache/create_check.py" do
  source "create_check.py"
  owner "root"
  group "root"
  mode "0755"
  action :create
end

#Create Filesystem Check and Alarm
execute "create_check" do
  command "python /var/chef/cache/create_check.py -u #{node['cloud_monitoring']['rackspace_username']} -a #{node['cloud_monitoring']['rackspace_api_key']} -r #{node['cloud_monitoring']['rackspace_auth_region']} -i #{node.ipaddress} -p #{node['cloud_monitoring']['agent']['filesystem_period']} -t #{node['cloud_monitoring']['agent']['filesystem_timeout']}"      
  user "root"
end
