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
    orgs = JSON.parse(Mixlib::ShellOut.new('delivery api get orgs').run_command.stdout)
    orgs['orgs'].each do |org|
      JSON.parse(Mixlib::ShellOut.new("delivery api get orgs/#{org['name']}/projects/").run_command.stdout).each do |project|
        node.run_state['external_pipeline'] << project['name']
      end
    end
  end
  !node.run_state['external_pipeline'].include?(cb)
end
