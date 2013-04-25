# Description

This cookbook provides automated way to manage the various resources using the Rackspace Cloud Monitoring API.
Specifically this recipe will focus on main atom's in the system.

* Entities
* Checks
* Alarms
* Agents (soon)
* Agent Tokens (soon)

The cookbook also installs the python-pip package in Debian and RedHat based systems, and then uses pip to install the Rackspace Cloud Monitoring client, raxmon-cli, via pip

The raxmon-cli recipe in this cookbook is not automatically added by default.  To install raxmon-cli, add the cloud_monitoring::raxmon recipe to the run_list. 

To run this recipe manually from a managed cloud server use the following command:

$ ./mgc.sh --recipe "cloudmonitoring" --json '"cloud_monitoring" : { "bootstrapfile" : "/etc/raxmon/bootstrap.json", "rackspace_username" : "cloudusername", "rackspace_api_key" : "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"}' --force

# Requirements

## Supported OS (Rackspace Managed Cloud)

* RHEL 5.5
* RHEL 6.1
* CentOS 5.6
* CentOS 6.3
* Ubuntu 10.04
* Ubuntu 11.04
* Ubuntu 11.10
* Ubuntu 12.04

Requires Chef 0.7.10 or higher for Lightweight Resource and Provider support. Chef 0.8+ is recommended. While this
cookbook can be used in chef-solo mode, to gain the most flexibility, we recommend using chef-client with a Chef Server.

## Library Requirements

The inner workings of the library depend on [fog](https://github.com/fog/fog) which is used by the Ruby command line
client called [rackspace-monitoring-rb](https://github.com/racker/rackspace-monitoring-rb).  These are handled in the
instantiation and use of the Cookbook.

A Rackspace Cloud Hosting account is required to use this tool.  And a valid `username` and `api_key` are required to
authenticate into your account.

You can get one here [sign-up](https://cart.rackspace.com/cloud/?cp_id=cloud_monitoring).

### Raxmon Requirements

python and python-pip (installed by this cookbook) for the raxmon-cli install

### General Requirements
* You need to either set the attributes for your Rackspace username and api key in attributes/default.rb or create an encrypted data bag per the following setup steps:

## Setup

Take either step depending on your databag setup.

### I already have an encrypted_data_bag_secret file created and pushed out to your chef nodes

* Create the new encrypted data_bag
knife data bag create --secret-file <LOCATION/NAME OF SECRET FILE>  rackspace cloud

* Make the json file opened look like the following, then save and exit your editor:
```
{
  "id": "cloud",
  "username": "<YOUR CLOUD SERVER USERNAME>",
  "apikey": "<YOUR CLOUD SERVER API KEY>",
  "region": "<YOUR ACCOUNT REGION (us OR uk)>"
}
```

### I don't use an encrypted_data_bag_secret file
* Create a new secret file
`$ openssl rand -base64 512 | tr -d '\r\n' > /tmp/my_data_bag_key`

* The `/tmp/my_data_bag_key` (or whatever you called it in the above step) needs to be pushed out to your chef nodes to `/etc/chef/encrypted_data_bag_secret`

* Create the new encrypted data_bag
`$ knife data bag create --secret-file /tmp/my_data_bag_key rackspace cloud`

* Make the json file opened look like the following, then save and exit your editor:
```
{
  "id": "cloud",
  "username": "<YOUR CLOUD SERVER USERNAME>",
  "apikey": "<YOUR CLOUD SERVER API KEY>",
  "region": "<YOUR ACCOUNT REGION (us OR uk)>"
}
```

# Attributes

All attributes are namespaced under the `node['cloud_monitoring']` namespace.  This keeps everything clean and organized.

The following attributes are required, either in attributes/default.rb or an encrypted data bag called rackspace with an item of cloud:

* `node['cloud_monitoring']['rackspace_username']`
* `node['cloud_monitoring']['rackspace_api_key']`
* `node['cloud_monitoring']['rackspace_auth_region']`
  * This must be set to either 'us' or 'uk', depending on where your account was created

# Usage

This cookbook exposes many different elements of the Cloud Monitoring product. We'll go over some examples and best
practices for using this cookbook. The most widely used parts of the system are the three core Resources in the system `Entity`, `Check` and `Alarm`. So we'll cover those first and tackle The other primitives towards the end.

## Entity

The first element is the `Entity`.  The `Entity` maps to the target of what you're monitoring.  This in most cases
represents a server, loadbalancer or website.  However, there is some advanced flexibility but that is only used in rare cases. The first use case we will show is populating your chef nodes in Cloud Monitoring...

Learn more about all these concepts in the docs and specifically the
[Concepts](http://docs.rackspacecloud.com/cm/api/v1.0/cm-devguide/content/concepts-key-terms.html) section of the
developer guide.

```ruby
cloud_monitoring_entity "#{node.hostname}-manual" do
  ip_addresses        'default' => node[:ipaddress]
  metadata            'environment' => 'dev', :more => 'meta data'
  rackspace_username  'joe'
  rackspace_api_key   'XXX'
  action :create
end
```
Upon execution of this code, if you viewed the `/entities` API call you would see an `Entity` labeled whatever the hostname of the machine.

Most of the fields are optional, you can even specify something as minimal as:

```ruby
cloud_monitoring_entity "#{node.hostname}" do
  rackspace_username  'joe'
  rackspace_api_key   'XXX'
  action :create
end
```

This operation is idempotent, and will select the node based on the name of the resource, which maps to the label of the
entity.  This is ***important*** because this pattern is repeated through out this cookbook.  If an attribute of the
resource changes the provider will issue a `PUT` instead of a `POST` to update the resource instead of creating another
one.

This will set an attribute on the node `node[:cloud_monitoring][:entity_id]`.  This attribute will be saved in the
chef server.  It is bi-directional, it can re-attach your cloud monitoring entities to your chef node based on the
label.  Keep in mind nothing is removed unless explicitly told so, like most chef resources.


## Check

The check is the way to start collecting data.  The stanza looks very similar to the `Entity` stanza except the accepted
parameters are different, it is seen more as the "what" of monitoring.

***Note: you must either have the attribute assigned `node[:cloud_monitoring][:entity_id]` or pass in an entity_id
explicitly so the Check knows which node to create it on.***

Here is an example of a ping check:

```ruby
cloud_monitoring_check  "ping" do
  target_alias          'default'
  type                  'remote.ping'
  period                30
  timeout               10
  monitoring_zones_poll ['mzord']
  rackspace_username    'joe'
  rackspace_api_key     'XXX'
  action :create
end
```

This will create a ping check that is scoped on the `Entity` that was created above.  In this case, it makes sense,
however sometimes you want to be specific about which node to create this check on.  If that's the case, then passing in
an `entity_id` will allow you to do that.

This block will create a ping check named "ping" with 30 second interval from a single datacenter "mzord".  It will
execute the check against the target_alias default, which is the chef flagged ipaddress above.

Creating a more complex check is just as simple, take HTTP check as an example.  There are multiple options to pass in
to run the check. This maps very closely to the API, so you have a details hash at your disposal to do that.

```ruby
cloud_monitoring_check  "http" do
  target_alias          'default'
  type                  'remote.http'
  period                30
  timeout               10
  details               'url' => 'http://www.google.com', 'method' => 'GET'
  monitoring_zones_poll ['mzord', 'mzdfw']
  rackspace_username    'joe'
  rackspace_api_key     'XXX'
  action :create
end
```

## Alarm

The `Alarm` is the way to specify a threshold in Cloud Monitoring and connect that to sending an alert to a customer.
Without an `Alarm` a user would never receive an alert based on a failure, warning or success.  An `Alarm` is scoped on
an entity and points to a check id or a check type.

An Alarm state is the combination of a Check + Alarm + Dimension.  Dimensions are additional complexity which I won't go
into here but they allow you arbitrarily nest information from the edge.

Alarms in the public API take a couple critical fields.  A notification plan id and a "criteria".  The notification plan
id points at a notification plan to execute upon a state transitioning.  The criteria describes the conditions to
generate an alert.

There are some guides describing how to best threshold for certain events, and there is also a built in alarm examples
API that is very powerful.  This [Alarm Examples
API](http://docs.rackspacecloud.com/cm/api/v1.0/cm-devguide/content/service-alarm-examples.html) is exposed in this
recipe indirectly through the alarm `cloud_monitoring_alarm` stanza.  Look at an example below:

```ruby
cloud_monitoring_alarm  "ping alarm" do
  check_label           'ping'
  example_id            'remote.ping_packet_loss'
  notification_plan_id  'npBLAH'
  action :create
end
```

This is a creating an alarm that checks for ping packet loss, if we look at a snippet from the JSON payload of the
alarm_examples API it looks something like this...

```javascript
...
    {
        "id": "remote.ping_packet_loss",
        "label": "Ping packet loss",
        "description": "Alarm which returns WARNING if the packet loss is greater than 5% and CRITICAL if it's greater than 20%",
        "check_type": "remote.ping",
        "criteria": "if (metric['available'] < 80) {\n  return CRITICAL, \"Packet loss is greater than 20%\"\n}\n\nif (metric['available'] < 95) {\n  return WARNING, \"Packet loss is greater than 5%\"\n}\n\nreturn OK, \"Packet loss is normal\"\n",
        "fields": []
    }
...
```


There is templating capability in the alarm_examples API call so if I were to use an example that would require this
functionality, I could specify `example_values` which would template the call.

Below is a new example of a templated alarm example as applied to an SSH check.

```javascript
...
    {
        "id": "remote.ssh_fingerprint_match",
        "label": "SSH fingerprint match",
        "description": "Alarm which returns CRITICAL if the SSH fingerprint doesn't match the provided one",
        "check_type": "remote.ssh",
        "criteria": "if (metric['fingerprint'] != \"${fingerprint}\") {\n  return OK, \"SSH fingerprint didn't match the expected one ${fingerprint}\"\n}\n\nreturn OK, \"Got expected SSH fingerprint (${fingerprint})\"\n",
        "fields": [
            {
                "name": "fingerprint",
                "description": "Expected SSH fingerprint",
                "type": "string"
            }
        ]
    },
...
```

Here is the corresponding check.

```ruby
cloud_monitoring_check  "ssh check name" do
  target_alias          'default'
  type                  'remote.ssh'
  period                30
  timeout               10
  monitoring_zones_poll ['mzord']
  action :create
end
```

And the alarm, notice the example_values hash.


```ruby
cloud_monitoring_alarm  "ssh alarm" do
  check_label           'ssh check name'
  example_id            'remote.ssh_fingerprint_match'
  example_values        "fingerprint" => node[:ssh][:fingerprint]
  notification_plan_id  'npBLAH'
  action :create
end
```

You'll also notice the check_label reference doesn't exist in the API, but the cookbook makes this much easier to
connect to other related objects.


If you wanted to use your own threshold then you could specify criteria in the alarm block.

```ruby
cloud_monitoring_alarm  "ping alarm" do
  check_label           'ping'
  criteria              "if (metric['available'] < 100) { return CRITICAL, 'Availability is at ${available}' }"
  notification_plan_id  'npBLAH'
  action                :create
end
```

