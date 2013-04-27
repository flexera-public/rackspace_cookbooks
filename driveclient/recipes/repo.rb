#
# Cookbook Name:: driveclient
# Recipe:: repo
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

case node[:platform]
when "redhat","centos"
  include_recipe "yum"

  yum_repository "drivesrvr" do
    description "RCBU agent repo"
    url "http://agentrepo.drivesrvr.com/redhat/"
    action :add
  end
when "ubuntu"
  include_recipe "apt"

  apt_repository "driveclient" do
    uri "[arch=amd64] http://agentrepo.drivesrvr.com/debian/"
    distribution "serveragent"
    components ["main"]
    key "repo-public.key"
  end
end
