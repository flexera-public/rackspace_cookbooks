#
# Cookbook Name:: driveclient
# Recipe:: default
#
# Copyright 2011, Rackspace Hosting
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
include_recipe "driveclient::repo"

if node.recipes.include?("managed-cloud") and File.exists?("/root/.noupdate")
  log "The Customer does not want the driveclient agent automatically installed."
else
  case node[:platform]
    when "redhat", "centos"
      include_recipe "yum-cron"
    when "ubuntu", "debian"
      include_recipe "unattended-upgrades"
  end
  
  package "driveclient" do
    action :upgrade
  end
  
  template node[:driveclient][:bootstrapfile] do
    source "bootstrap.json.erb"
    owner  "root"
    group  "root"
    mode   "0600"
    variables(
      :setup => true
    )
    not_if "grep 'Registered' #{node[:driveclient][:bootstrapfile]} |grep 'true'"
  end
  
  service "driveclient" do
    supports :restart => true, :stop => true, :status => true
    action [:enable, :start]
    subscribes :restart, resources(:template => node[:driveclient][:bootstrapfile]), :immediately
  end
  
  log "Sleeping #{node[:driveclient][:sleep]}s to wait for RCBU registration."
  ruby_block "Sleeping #{node[:driveclient][:sleep]}s" do
    block do
      sleep(node[:driveclient][:sleep])
    end
  end
  
  file node[:driveclient][:bootstrapfile] do
    backup false
    not_if "grep 'Registered' #{node[:driveclient][:bootstrapfile]} |grep 'true'"
    action :delete
  end
  
  ruby_block "report_failed_registration" do
    block do
      Chef::Application.fatal!("driveclient failed to register.")
    end
    not_if "test -f #{node[:driveclient][:bootstrapfile]}"
  end

  case node[:platform]
  when "redhat","centos"
    cookbook_file "/etc/monit.d/driveclient.conf" do
      source "driveclient.conf"
      mode "0644"
      owner "root"
      group "root"
      backup 0
      only_if "test -d /etc/monit.d"
    end
  when "ubuntu","debian"
    cookbook_file "/etc/monit/conf.d/driveclient.conf" do
      source "driveclient.conf"
      mode "0644"
      owner "root"
      group "root"
      backup 0
      only_if "test -d /etc/monit/conf.d"
    end
  end

  execute "Restart monit" do
    command "/etc/init.d/monit restart"
    only_if "test -x /etc/init.d/monit"
  end
end
