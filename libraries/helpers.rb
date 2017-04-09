#
# Cookbook:: _build
# Library:: helpers
#
# Copyright:: 2017, Nathan Cerny
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

def external?(cb)
  node.run_state['external_pipeline'] ||= []
  if node.run_state['external_pipeline'].empty?
    delivery_api_get('delivery api get orgs')['orgs'].each do |org|
      delivery_api.get("orgs/#{org['name']}/projects").each do |project|
        node.run_state['external_pipeline'] << project['name']
      end
    end
  end
  !node.run_state['external_pipeline'].include?(cb)
end

def delivery_api_get(path)
  ent_name = node['delivery']['change']['enterprise']
  request_url = "/api/v0/e/#{ent_name}/#{path}"
  change = ::JSON.parse(::File.read(::File.expand_path('../../../../../../../change.json', node['delivery_builder']['workspace'])))
  uri = URI.parse(change['delivery_api_url'])
  http_client = Net::HTTP.new(uri.host, uri.port)

  if uri.scheme == 'https'
    http_client.use_ssl = true
    http_client.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  headers = {
    'chef-delivery-token' => change['token'],
    'chef-delivery-user' => 'builder',
  }
  result = http_client.get(request_url, headers)
  JSON.parse(result.body)
end
