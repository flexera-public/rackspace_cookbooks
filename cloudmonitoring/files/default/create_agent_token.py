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
    parser.add_option("-o", "--hostname",
                      action="store", type='string', dest="hostname")

    (options, args) = parser.parse_args()

    return options.username, options.api_key, options.hostname, options.region

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

    def get_agent_tokens(self):
        return self.__request("/agent_tokens")

    def create_token(self, data):
        return self.__request("/agent_tokens/", data)

    def get_my_token(self, hostname):
        my_key = ''
        d = self.get_agent_tokens()['values']
        for v in d:
            if v['label'] == hostname: 
                my_key = v['id']
        return my_key
        
if __name__ == "__main__":

    args = main()

    username = args[0] 
    api_key = args[1] 
    hostname = args[2] 
    region = args[3] 

    if not hostname:
        hostname = socket.gethostname()

    uk_user = False
    if region == 'uk':
        uk_user = True

    try:
        cm = CloudMonitoring(username, api_key, uk_user)
    except urllib2.HTTPError, err:
        raise

    try: 
        agent_token = cm.get_my_token(hostname)
    except urllib2.HTTPError, err:
        raise

    if not agent_token:
        try:            
            new_token = cm.create_token({"label": hostname})
        except urllib2.HTTPError, err:
            raise
        print new_token
    else:
        print agent_token


