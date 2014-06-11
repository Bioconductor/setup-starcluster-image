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

unless yamlconfig.has_key? "install_annotation_packages"
    raise "no 'install_annotation_packages' key in config.yml!"
end

unless ["FalseClass", "TrueClass"].include? yamlconfig['install_annotation_packages'].class.to_s
    raise "'install_annotation_packages' key  in config.yml has invalid value (must be TRUE or FALSE)!"
end

username = nil
["vagrant", "ubuntu"].each do |user|
    res = `grep "^#{user}" /etc/passwd`
    username = user unless res.empty?
end


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
    not_if {File.exists?("/downloads/#{r_version}")}
end

execute "configure R" do
    command "./configure --enable-R-shlib"
    cwd "/downloads/#{r_version}"
    user "root"
    not_if {File.exists?("/downloads/#{r_version}/config.log")}
    #not_if "tail -1 /downloads/#{r_version}/config.log|grep -q 'configure: exit 0'"
end

execute "make R" do
    command "make -j > /downloads/R-make.out 2>&1"
    cwd "/downloads/#{r_version}"
    user "root"
    not_if {File.exists? "/downloads/#{r_version}/bin/R"}
end

execute "install R" do
    command "make install"
    cwd "/downloads/#{r_version}"
    user "root"
    not_if {File.exists? "/usr/local/bin/R"}
end

# if we're NOT on ec2...
res = `curl -s http://169.254.169.254/latest/meta-data/`
if res.empty?
    mpi_packs = %w(libmpich2-3 libmpich2-dev libopenmpi-dev libopenmpi1.3 mpich2 openmpi-bin openmpi-checkpoint openmpi-common)
    for mpi_pack in mpi_packs
        package mpi_pack do
            action :install
        end
    end    
end

# XML/RCurl prereqs
%w(libcurl4-openssl-dev libxml2-dev).each do |pkg|
    package pkg do
        action :install
    end
end

execute "install R packages" do
    command "Rscript /vagrant/install.R > /downloads/install-rpacks.out 2>&1"
    environment({"USE_DEVEL" => yamlconfig['use_devel'].to_s.upcase,
        "INSTALL_ANNOTATION_PACKAGES" =>
        yamlconfig['install_annotation_packages'].to_s.upcase})
    user "root"
    # run always?
    #not_if 'ls /usr/local/lib/R/library| grep -q "^VariantAnnotation$"'
end

# ensemblVEP deps
%w(libdbi-perl libdbd-mysql-perl libarchive-zip-perl).each do |pkg|
    package pkg do
        action :install
    end
end

maxVep = `echo "cat(unname(unlist(ensemblVEP::currentVEP())))"|R --slave`
vepUrl = "https://codeload.github.com/Ensembl/ensembl-tools/zip/release/#{maxVep}"
vepZip = "ensembl-tools-release-#{maxVep}.zip"
vepDir = vepZip.sub(".zip", "")

remote_file "/downloads/#{vepZip}" do
    source vepUrl
end

execute "unzip vep" do
    command "unzip #{vepZip}"
    user "root"
    cwd "/downloads"
    not_if {File.exists? "/downloads/#{vepDir}"}
end

execute "rename vep" do
    command "mv variant_effect_predictor /usr/local"
    user "root"
    cwd "/downloads/#{vepDir}/scripts"
    not_if {File.exists? "/usr/local/variant_effect_predictor"}
end

execute "add vep to path" do
    command "echo 'export PATH=$PATH:/usr/local/variant_effect_predictor' >> /etc/profile"
    user "root"
    not_if "grep -q variant_effect_predictor /etc/profile"
end

# needed for Rstudio (server)
execute "add vep to Renviron.site path" do
    command "echo 'PATH=${PATH}:/usr/local/variant_effect_predictor' > Renviron.site"
    user "root"
    cwd "/usr/local/lib/R/etc"
    not_if {File.exists? "/usr/local/lib/R/etc/Renviron.site"}
end



execute "install vep" do
    command "perl INSTALL.pl -a a && touch vep_is_installed"
    cwd "/usr/local/variant_effect_predictor"
    user "root"
    not_if {File.exists? "/usr/local/variant_effect_predictor/vep_is_installed"}
end

# # install some gems
# %w(nokogiri pry pry-doc pry-nav).each do |gem|
#     chef_gem gem do
#         action :install
#         options("--no-ri --no-rdoc")
#     end
# end

# execute "install some gems" do
#     command "gem install --no-ri --no-rdoc pry pry-nav pry-doc"
#     user "root"
#     not_if 'gem list|grep -q "^pry "'
# end


# require 'nokogiri'

# install rstudio server

%w(gdebi-core libapparmor1).each do |pkg|
    package pkg do
        action :install
    end
end

remote_file "/downloads/rstudio.html" do
    source "http://www.rstudio.com/products/rstudio/download-server/"
end

lines = File.readlines("/downloads/rstudio.html")
count = 0
for line in lines
  if line =~ /<strong>64bit<\/strong><br \/>/
    break
  else
    count += 1
  end
end

version = nil
for i in count..lines.length
  line = lines[i]
  if line =~ /^Version:/
    #lala
    version = line.split(" ")[1].split("<").first.strip
    encoding_options = {:invalid => :replace,
        :undef => :replace, :replace => '', :universal_newline => true}
    version = version.encode(Encoding.find('ASCII'), encoding_options)
    # puts "HOKUM version: .#{version}."
    # version.each_byte do |c|
    #     puts c
    # end
    break
  end
end

raise "couldn't get rstudio server version" if version.nil?

url = "http://download2.rstudio.org/rstudio-server-#{version}-amd64.deb"

puts "version: .#{version}., url: .#{url}."

debfile = url.split("/").last

remote_file "/downloads/#{debfile}" do
    source url
end

dpkg = `dpkg -s rstudio-server`
need_install = dpkg.empty?
unless need_install
    installed_version = dpkg.split("\n").find{|i| i=~ /^Version/}.split(" ").last
    need_install = (installed_version != version)
end

execute "install rstudio-server" do
    command "gdebi -n #{debfile}"
    user "root"
    cwd "/downloads"
    only_if {need_install}
end


execute "change #{username} password" do
    command "echo #{username}:bioc | chpasswd"
    user "root"
    # fixme guard this somehow?
end

# clear history....
