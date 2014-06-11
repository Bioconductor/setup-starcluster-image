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

# config.ssh.username



require 'yaml'

configfile = "/vagrant/config.yml"
unless File.exists? configfile
    raise "config.yml does not exist!"
end

yamlconfig = YAML.load_file configfile

unless yamlconfig.has_key? "r_version"
    raise "no 'r_version' key in config.yml!"
end

unless yamlconfig.has_key? "use_devel"
    raise "no 'use_devel' key in config.yml!"
end

unless ["FalseClass", "TrueClass"].include? yamlconfig['use_devel'].class.to_s
    raise "'use_devel' key  in config.yml has invalid value (must be TRUE or FALSE)!"
end


# CRAN_RSOURCE_TOPDIR="R-devel"
# CRAN_TARBALL="$CRAN_RSOURCE_TOPDIR.tar.gz"
# CRAN_TARBALL_URL="ftp://ftp.stat.math.ethz.ch/Software/R/$CRAN_TARBALL"
#CRAN_RSOURCE_TOPDIR="R-3.1.0"
#CRAN_TARBALL="R-3.1.0.tar.gz"
#CRAN_TARBALL_URL="http://cran.r-project.org/src/base/R-3/$CRAN_TARBALL"

r_version = yamlconfig["r_version"]
tarball = "#{r_version}.tar.gz"

tarball_url = nil
if r_version =~ /^R-[0-9]/
    tarball_url = "http://cran.r-project.org/src/base/R-#{r_version.split("")[2]}/#{tarball}"
else
    tarball_url = "ftp://ftp.stat.math.ethz.ch/Software/R/#{tarball}"
end

directory "/downloads" do
  owner "root"
  group "root"
  #mode 00644
  mode "0755"
  action :create
end


remote_file "/downloads/#{tarball}" do
    source tarball_url
end

execute "echo message" do
  command "echo '#{message}'"
  #command "touch /home/vagrant/futz"
  action :run
end

execute "apt-get update" do
  command "apt-get update"
  user "root"
  action :run
  # how to guard?
end


execute "install R build deps" do
  command "apt-get build-dep -y r-base"
  user "root"
  action :run
  not_if 'dpkg --get-selections|grep -q "^xvfb\s"'
end

execute "untar R tarball" do
    command "tar zxf #{tarball}"
    cwd "/downloads"
    user "root"
    #rdir = "/downloads/#{r_version}"
    not_if(File.exists?("/downloads/#{r_version}"))
end

execute "configure R" do
    command "./configure --enable-R-shlib"
    cwd "/downloads/#{r_version}"
    user "root"
    not_if(File.exists?("/downloads/#{r_version}/config.log"))
    #not_if "tail -1 /downloads/#{r_version}/config.log|grep -q 'configure: exit 0'"
end

execute "make R" do
    command "make -j > /downloads/R-make.out 2>&1"
    cwd "/downloads/#{r_version}"
    user "root"
    not_if File.exists? "/downloads/#{r_version}/bin/R"
end

execute "install R" do
    command "make install"
    cwd "/downloads/#{r_version}"
    user "root"
    not_if File.exists? "/usr/local/bin/R"
end

execute "install R packages" do
    command "Rscript /vagrant/install.R"
    environment({"USE_DEVEL" => yamlconfig['use_devel'].to_s.upcase})
    user "root"
    # run always?
    not_if 'ls /usr/local/lib/R/library| grep -q "^VariantAnnotation$"'
end

# libdbi-perl libdbd-mysql-perl

# install rstudio server

# clear history....
