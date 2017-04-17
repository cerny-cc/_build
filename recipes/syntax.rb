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
  execute 'git config --global user.email "builder@cerny.cc"' do
    not_if 'git config --get user.email | grep builder@cerny.cc'
  end

  execute 'git config --global user.name "cerny-cc automated build"' do
    not_if 'git config --get user.name | grep "cerny-cc automated build"'
  end

  change = ::JSON.parse(::File.read(::File.expand_path('../../../../../../../change.json', node['delivery_builder']['workspace'])))
  directory "#{ENV['HOME']}/.delivery"
  file "#{ENV['HOME']}/.delivery/api-tokens" do
    content "automate.cerny.cc,cerny,builder|#{change['token']}"
  end

  cookbook_directory = File.join(node['delivery']['workspace']['cache'], 'cookbooks')

  execute '_pipeline :: Clone project from Chef Automate Workflow' do
    command 'delivery clone _pipeline --no-spinner'
    cwd cookbook_directory
  end

  deps = Mash.new
  deps[:supermarket] = []
  deps[:git] = Mash.new

  changed_cookbooks.each do |cookbook|
    cb = Chef::Cookbook::CookbookVersionLoader.new(cookbook.path)
    cb.load!

    berks ||= {}
    if ::File.exist?("#{cookbook.path}/Berksfile")
      ::File.read("#{cookbook.path}/Berksfile").each_line do |line|
        next unless line =~ /^\s*cookbook/
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
        deps[:supermarket] << k
      end
    end
  end
  # external.raw_data = Chef::Mixin::DeepMerge.deep_merge(external.to_h, deps)
  # external.save
  file "#{cookbook_directory}/_pipeline/external_cookbooks.json" do
    content lazy { JSON.generate(Chef::Mixin::DeepMerge.deep_merge(JSON.parse(::File.read("#{cookbook_directory}/_pipeline/external_cookbooks.json"), deps))) }
    notifies :run, 'execute[_pipeline :: Commit Changes]', :immediately
  end

  execute '_pipeline :: Commit Changes' do
    command "git commit -m update-dependencies-for-#{cookbook_name}"
    cwd "#{cookbook_directory}/_pipeline"
    # Adding as part of the guard feels dirty, but it makes the recipe more convergent -- we don't have a resource that always runs, or build logic off of unknown wording in future versions of git.
    not_if 'git add . && git update-index -q --ignore-submodules --refresh && git diff-index --quiet delivery/master --'
    notifies :run, 'execute[_pipeline :: Submit change to Chef Automate Workflow]', :immediately
    action :nothing
  end

  execute '_pipeline :: Submit change to Chef Automate Workflow' do
    command 'delivery review --no-spinner --no-open'
    cwd "#{cookbook_directory}/_pipeline"
    action :nothing
  end
end

include_recipe 'delivery-truck::syntax'
