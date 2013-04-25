maintainer       "Rackspace Hosting"
maintainer_email "bk.box@rackspace.com"
license          "Apache 2.0"
description      "Installs/Configures driveclient"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "1.0.0"

%w{ redhat centos ubuntu }.each do |os|
  supports os
end

%w{ apt yum }.each do |cb|
  depends cb
end
