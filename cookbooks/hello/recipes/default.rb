#
# Cookbook Name:: helloworld
# Recipe:: default
#
# Copyright 2012, Jonathan Klinginsmith
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
#

# If a message was provided then display it; otherwise, say 'Hello World'.
message = node.has_key?(:message) ? node[:message] : "Hello World"

execute "echo message" do
  command "echo '#{message}'"
  #command "touch /home/vagrant/futz"
  action :run
end

