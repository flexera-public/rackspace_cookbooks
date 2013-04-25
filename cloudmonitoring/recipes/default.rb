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

if File.exists?("/root/.noupdate") and node['cloud_monitoring']['status'] == "prod"
  Chef::Log.info "The customer does not want the monitoring agent."
else

  case node[:platform]
  when "redhat", "centos"

    major_version = node['platform_version'].split('.').first.to_i
    if major_version < 6

      cookbook_file "/etc/pki/rpm-gpg/signing-key-rhel5.asc" do
        source "signing-key-rhel5.asc"
        action :create
      end

      cookbook_file "/etc/yum.repos.d/raxmon.repo" do
        source "rhel-raxmon-5.repo"
        action :create
      end

    else

      cookbook_file "/etc/pki/rpm-gpg/signing-key.asc" do
        source "signing-key.asc"
        action :create
      end

      cookbook_file "/etc/yum.repos.d/raxmon.repo" do
        source "rhel-raxmon.repo"
        action :create
      end

    end

    execute "yum -q clean metadata"  # Prevents failures on yum -q makecache due to out-of-date metadata files
    execute "yum -q makecache"
    ruby_block "reload-internal-yum-cache" do
      block do
        Chef::Provider::Package::Yum::YumCache.instance.reload
      end
    end

  when "ubuntu"

    cookbook_file "/tmp/signing-key.asc" do
      source "signing-key.asc"
      action :create
    end

    execute "apt-key add /tmp/signing-key.asc" do
      not_if "apt-key list | grep monitoring@rackspace.com"
    end

    execute "apt-get update" do
      action :nothing
    end

    template "/etc/apt/sources.list.d/racmon.list" do
      owner "root"
      mode "0644"
      source "raxmon.list.erb"
      notifies :run, resources("execute[apt-get update]"), :immediately
    end
  end


  #Install all our pre-reqs
  case node['platform']
  when "ubuntu","debian"
    package( "libxslt-dev" ).run_action( :install )
    package( "libxml2-dev" ).run_action( :install )


  when "redhat","centos","fedora", "amazon","scientific"
    package( "libxslt-devel" ).run_action( :install )
    package( "libxml2-devel" ).run_action( :install )


    major_version = node['platform_version'].split('.').first.to_i
    if platform_family?('rhel') && major_version < 6
     package( "python-setuptools" ).run_action( :install )
     package( "python-simplejson" ).run_action( :install )
    end
  end

  if File.exists?('/etc/rackspace/datacenter') and File.readable?('/etc/rackspace/datacenter')
  dc = File.open('/etc/rackspace/datacenter') {|f| f.readline}
  node['cloud_monitoring']['datacenter'] = dc.strip
  Chef::Log.info "Datacenter is: #{node['cloud_monitoring']['datacenter']}"

  case node['cloud_monitoring']['datacenter']
     when "SAT1", "SAT2", "IAD1", "IAD2", "DFW1", "ORD1"
        node.set['cloud_monitoring']['rackspace_auth_region'] = 'us'
        node.set['cloud_monitoring']['rackspace_auth_url'] = 'https://identity.api.rackspacecloud.com/v2.0'
        node.set['cloud_monitoring']['rackspace_rb_auth_url'] = 'identity.api.rackspacecloud.com'
        Chef::Log.info "Setting region to: #{node['cloud_monitoring']['rackspace_auth_region']}"

     when "LON3" 
        node.set['cloud_monitoring']['rackspace_auth_region']  = 'uk'
        node.set['cloud_monitoring']['rackspace_auth_url'] = 'https://lon.identity.api.rackspacecloud.com/v2.0'
        node.set['cloud_monitoring']['rackspace_rb_auth_url'] = 'lon.identity.api.rackspacecloud.com'
        Chef::Log.info "Setting region to: #{node['cloud_monitoring']['rackspace_auth_region']}"
     end
  end
    #Calling the other recipes needed for a full install. This could be moved to a role or run_list. 
    include_recipe "cloudmonitoring::agent"

end
