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

chef_gem 'train' do
  compile_time false
end

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
  db = 'external_pipeline'
  dbi = 'cookbooks'

  chef_data_bag(db) do
    action :nothing
  end.run_action(:create)

  chef_data_bag_item("#{db}/#{dbi}") do
    action :nothing
    complete false
  end.run_action(:create)

  external = data_bag_item(db, dbi)

  deps = Mash.new
  changed_cookbooks.each do |cookbook|
    cb = Chef::Cookbook::CookbookVersionLoader.new(cookbook.path)
    cb.load!

    cb.metadata.dependencies.each do |k, _|
      deps[k] = '0.0.0' if external?(k)
    end
  end
  external = deps.merge(external)
  external.save
end

puts "Dependencies: #{node['delivery']['config']['dependencies']}"
