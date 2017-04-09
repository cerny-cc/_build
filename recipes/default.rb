#
# Cookbook:: _build
# Recipe:: default
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
# F75ruqePSTN*MqQouNm^Y&mdHsLg2uS8$2SP&K9zNW&Mc*SZ!VN%S@K5HAnE4zT8JI%xsTO6b3cRYw*Zn!zdmSg&gS3n@9gH3

chef_gem 'train'

yum_repository 'packages-microsoft-com-prod' do
  description 'Microsoft Prod'
  baseurl 'https://packages.microsoft.com/rhel/7/prod/'
  gpgkey 'https://packages.microsoft.com/keys/microsoft.asc'
  action :create
end

package 'powershell'

include_recipe 'delivery-truck::default'

return unless workflow_phase.eql?('syntax')

DeliverySugar::ChefServer.new(delivery_knife_rb).with_server_config do
  changed_cookbooks.each do |cookbook|
    cb = Chef::Cookbook::CookbookVersionLoader.new(cookbook.path)
    cb.load!
    deps = Mash.new
    cb.metadata.dependencies.each do |k, _|
      deps[k] = {}
    end
    chef_data_bag_item 'workflow/external' do
      raw_data deps
    end
  end
end

puts node['delivery']['config']['dependencies']
