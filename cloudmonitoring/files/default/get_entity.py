#  Copyright 2012 Rackspace
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

import urllib2
from optparse import OptionParser
import socket

try:
    import json
except ImportError:
    import simplejson as json


class RestHTTPErrorProcessor(urllib2.BaseHandler):
    def http_error_201(self, request, response, code, message, headers):
        return response

    def http_error_204(self, request, response, code, message, headers):
        return response

def main():
    usage = "usage: %prog [options] arg"
    parser = OptionParser(usage)
    parser.add_option("-u", "--username",
                      action="store", type='string', dest="username")
    parser.add_option("-a", "--api_key",
                      action="store", type='string', dest="api_key")
    parser.add_option("-r", "--region",
                      action="store", type='string', dest="region")
    parser.add_option("-i", "--ip",
                      action="store", type='string', dest="ip")
    parser.add_option("-o", "--hostname",
                      action="store", type='string', dest="hostname")

    (options, args) = parser.parse_args()

    return options.username, options.api_key, options.ip, options.region, options.hostname

def request(url, auth_token=None, data=None):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    if auth_token:
        headers['X-Auth-Token'] = auth_token
    if data:
        data = json.dumps(data)

    req = urllib2.Request(url, data, headers)
    res = urllib2.build_opener(RestHTTPErrorProcessor).open(req)

    if res.code == 200:
        return json.loads(res.read())
    elif res.code == 201 or res.code == 204:
        return res.headers['Location'].rsplit("/")[-1]

def put_request(url, auth_token=None, data=None):
    headers = {
        "Content-Type": "application/json",
        "Accept": "application/json"
    }

    if auth_token:
        headers['X-Auth-Token'] = auth_token
    if data:
        data = json.dumps(data)

    req = urllib2.Request(url, data, headers)
    req.get_method = lambda: 'PUT'
    res = urllib2.build_opener(RestHTTPErrorProcessor).open(req)

    if res.code == 200:
        return json.loads(res.read())
    elif res.code == 201 or res.code == 204:
        return res.headers['Location'].rsplit("/")[-1]
    

def auth(username, api_key, uk=False):
    url = None

    if uk:
        url = 'https://lon.identity.api.rackspacecloud.com/v2.0/tokens'
    else:
        url = 'https://identity.api.rackspacecloud.com/v2.0/tokens'

    data = {
        "auth": {
            "RAX-KSKEY:apiKeyCredentials": {
                "username": username,
                "apiKey": api_key
            }
        }
    }

    return request(url, data=data)


class CloudMonitoring:
    def __init__(self, username, api_key, uk=False):
        auth_access = auth(username, api_key, uk)["access"]
        self.token = auth_access["token"]["id"]
        self.base_url = filter(lambda entry: entry["name"] == "cloudMonitoring", auth_access["serviceCatalog"])[0]["endpoints"][0]["publicURL"]

    def __request(self, path, data=None):
        return request(self.base_url + path, self.token, data)

    def __putrequest(self, path, data=None):
        return put_request(self.base_url + path, self.token, data)

    def __paginated_request(self, path):
        items = []
        next_href = self.base_url + path
        while next_href:
            result = request(next_href, self.token)
            items += result["values"]
            next_href = result["metadata"]["next_href"]
        return items

    def get_entities(self):
        return self.__paginated_request("/entities")

    def get_entity_by_ip(self, ip_address):
        my_entity = ''
        for entities in self.get_entities():
                if entities['ip_addresses'] is not None:
                    for addr in entities['ip_addresses'].values():
                        if addr == ip_address: 
                            my_entity = entities['id']
        return my_entity

    def set_agent_id(self, entity_id, data):
        return self.__putrequest("/entities/%s" % entity_id, data)


if __name__ == "__main__":
   
    args = main()

    username = args[0] 
    api_key = args[1] 
    ip_address = args[2] 
    region = args[3] 
    hostname = args[4] 

    if not hostname:
        hostname = socket.gethostname()

    uk_user = False
    if region == 'uk':
        uk_user = True

    cm = CloudMonitoring(username, api_key, uk_user)
    entity = cm.get_entity_by_ip(ip_address)

    if entity:
        try:
            agent_id = cm.set_agent_id(entity, {
                "agent_id": hostname
                })

        except urllib2.HTTPError, err:
           if err.code != 400:
               raise
    else:
         print "Entity for server " + hostname + " cannot be found."
