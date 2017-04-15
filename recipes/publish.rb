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

  deps = {}
  deps[:supermarket] = []
  deps[:git] = {}
  deps[:github] = {}

  changed_cookbooks.each do |cookbook|
    cb = Chef::Cookbook::CookbookVersionLoader.new(cookbook.path)
    cb.load!

    berks = {}
    if ::File.exist?("#{cookbook.path}/Berksfile")
      ::File.read("#{cookbook.path}/Berksfile").each_line do |line|
        next unless line ~= /^\s*cookbook/
        h = line.split(',').map { |a| a.strip.delete('"').split }.to_h
        if h.include?('git:')
          h[:source] = :git
          h[:uri] = h['git:']
          h.delete('git:')
        elsif h.include?('github:')
          h[:source] = :git
          h[:uri] = "https://github.com/#{h['github:']}.git"
          h.delete('github:')
        else
          h[:source] = :other
        end
        berks[h['cookbook']] ||= {}
        berks[h['cookbook']] = h
      end
    end

    cb.metadata.dependencies.each do |k, _|
      if berks.include?(k)
        deps[berks[k][:source]] ||= {}
        deps[berks[k][:source]][k] ||= {}
        deps[berks[k][:source]][k] = berks[k]
      else
        deps['supermarket'] << k
      end
    end
  end
  external.raw_data = deps.merge(external)
  external.save
end

# We don't want to publish cookbooks from berks.
if upload_cookbook_to_chef_server?
  changed_cookbooks.each do |cookbook|
    file "#{cookbook.name}_Berksfile" do
      action :nothing
      path ::File.join(cookbook.path, 'Berksfile')
      only_if { ::File.exist?(::File.join(cookbook.path, 'Berksfile')) }
    end.run_action(:delete)
  end
end

include_recipe 'delivery-truck::publish'
