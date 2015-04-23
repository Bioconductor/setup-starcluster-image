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

lines = File.readlines("/etc/lsb-release")
distrib_codename = lines.find{|i| i =~ /^DISTRIB_CODENAME/}.strip.split("=").last


r_version = yamlconfig["r_version"]
tarball = "#{r_version}.tar.gz"

tarball_url = nil
if r_version =~ /^R-[0-9]/
    tarball_url = "http://cran.r-project.org/src/base/R-#{r_version.split("")[2]}/#{tarball}"
else
    tarball_url = "ftp://ftp.stat.math.ethz.ch/Software/R/#{tarball}"
end

on_ec2 = true
# if we're NOT on ec2...
res = `curl -s http://169.254.169.254/latest/meta-data/`
if res.empty?
    on ec2 = false
end

## end config, start doing stuff 




if on_ec2 # and running ubuntu 13.04...

    execute "update apt sources" do
        command "sed -i -e 's/archive.ubuntu.com\|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list"
        user "root"        
        action :run
        # should probably guard this
    end


    execute "add to sources" do
        command "cat /vagrant/add_to_sources.txt | sed s/raring/#{distrib_codename}/g>> /etc/apt/sources.list"
        user "root"
        not_if "grep -q 'deb http://us.archive.ubuntu.com/ubuntu #{distrib_codename} main multiverse universe' /etc/apt/sources.list"
        action :run
    end

    execute "apt-get update" do
        command "apt-get update"
        user "root"
        action :run
    end


end


execute "apt-get update" do
  # the sed should probably not be run unconditionally,
  # but i got impatient
  command "sed -i -e 's/archive.ubuntu.com\|security.ubuntu.com/old-releases.ubuntu.com/g' /etc/apt/sources.list && apt-get update"
  user "root"
  action :run
  # how to guard?
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


unless on_ec2
    mpi_packs = %w(libmpich2-3 libmpich2-dev libopenmpi-dev libopenmpi1.3 mpich2 openmpi-bin openmpi-checkpoint openmpi-common)
    for mpi_pack in mpi_packs
        package mpi_pack do
            action :install
        end
    end    
end


execute "install R (dev) build deps" do
  command "apt-get build-dep -y r-base-dev"
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



if on_ec2

    %w(libreadline6-dev texlive-science texinfo
        texlive-fonts-extra dvipng libpng12-dev libpango1.0-dev shellinabox).each do |pkg|
        package pkg do
            action :install
        end
    end        
end

execute "configure R" do
    command "./configure --enable-R-shlib --with-cairo=yes"
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




# XML/RCurl prereqs
%w(libcurl4-openssl-dev libxml2-dev).each do |pkg|
    package pkg do
        action :install
    end
end

execute "remove lock files" do
    command "rm -rf /usr/local/lib/R/library/00LOCK*"
    user "root"
    only_if {File.exists? "/usr/local/lib/R/library"}
end

execute "install R packages" do
    command "Rscript /vagrant/install.R > /downloads/install-rpacks.out 2>&1"
    environment({"USE_DEVEL" => yamlconfig['use_devel'].to_s.upcase,
        "INSTALL_ANNOTATION_PACKAGES" =>
        yamlconfig['install_annotation_packages'].to_s.upcase})
    user "root"
    timeout 21600
    # run always?
    #not_if 'ls /usr/local/lib/R/library| grep -q "^VariantAnnotation$"'
end

# ensemblVEP deps
%w(libdbi-perl libdbd-mysql-perl libarchive-zip-perl).each do |pkg|
    package pkg do
        action :install
    end
end

ruby_block "set up VEP" do
    block do
        maxVep = `echo "cat(unname(unlist(ensemblVEP::currentVEP())))"|R --slave`
        vepUrl = "https://codeload.github.com/Ensembl/ensembl-tools/zip/release/#{maxVep}"
        vepZip = "ensembl-tools-release-#{maxVep}.zip"
        vepDir = vepZip.sub(".zip", "")

        rf = Chef::Resource::RemoteFile.new "/downloads/#{vepZip}", run_context
        rf.source vepUrl
        rf.run_action :create_if_missing

        ex = Chef::Resource::Execute.new "unzip vep", run_context
        ex.command  "unzip #{vepZip}"
        ex.user "root"
        ex.cwd "/downloads"
        ex.not_if {File.exists? "/downloads/#{vepDir}"}
        ex.run_action :run

        ex = Chef::Resource::Execute.new "rename vep", run_context
        ex.command "mv variant_effect_predictor /usr/local"
        ex.user "root"
        ex.cwd "/downloads/#{vepDir}/scripts"
        ex.not_if {File.exists? "/usr/local/variant_effect_predictor"}
        ex.run_action :run

        ex = Chef::Resource::Execute.new "add vep to path", run_context
        ex.command "echo 'export PATH=$PATH:/usr/local/variant_effect_predictor' >> /etc/profile" 
        ex.user "root"
        ex.not_if "grep -q variant_effect_predictor /etc/profile"
        ex.run_action :run

        ex = Chef::Resource::Execute.new "add vep to Renviron.site path", run_context
        ex.command "echo 'PATH=${PATH}:/usr/local/variant_effect_predictor' > Renviron.site"
        ex.user "root"
        ex.cwd "/usr/local/lib/R/etc"
        ex.not_if {File.exists? "/usr/local/lib/R/etc/Renviron.site"}
        ex.run_action :run

        ex = Chef::Resource::Execute.new "install vep", run_context
        ex.command "perl INSTALL.pl -a a && touch vep_is_installed"
        ex.cwd "/usr/local/variant_effect_predictor"
        ex.user "root"
        ex.not_if {File.exists? "/usr/local/variant_effect_predictor/vep_is_installed"}
        ex.run_action :run

    end
    action :create
end


# remote_file "/downloads/#{vepZip}" do
#     source vepUrl
# end

# execute "unzip vep" do
#     command "unzip #{vepZip}"
#     user "root"
#     cwd "/downloads"
#     not_if {File.exists? "/downloads/#{vepDir}"}
# end

# execute "rename vep" do
#     command "mv variant_effect_predictor /usr/local"
#     user "root"
#     cwd "/downloads/#{vepDir}/scripts"
#     not_if {File.exists? "/usr/local/variant_effect_predictor"}
# end

# execute "add vep to path" do
#     command "echo 'export PATH=$PATH:/usr/local/variant_effect_predictor' >> /etc/profile"
#     user "root"
#     not_if "grep -q variant_effect_predictor /etc/profile"
# end

# needed for Rstudio (server)
# execute "add vep to Renviron.site path" do
#     command "echo 'PATH=${PATH}:/usr/local/variant_effect_predictor' > Renviron.site"
#     user "root"
#     cwd "/usr/local/lib/R/etc"
#     not_if {File.exists? "/usr/local/lib/R/etc/Renviron.site"}
# end



# execute "install vep" do
#     command "perl INSTALL.pl -a a && touch vep_is_installed"
#     cwd "/usr/local/variant_effect_predictor"
#     user "root"
#     not_if {File.exists? "/usr/local/variant_effect_predictor/vep_is_installed"}
# end

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

ruby_block "install rstudio server" do
    block do

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

        rf = Chef::Resource::RemoteFile.new "/downloads/#{debfile}", run_context
        rf.source url
        rf.run_action :create_if_missing

        ex = Chef::Resource::Execute.new "install rstudio .deb file", run_context
        ex.command "gdebi -n #{debfile}"
        ex.user "root"  
        ex.cwd "/downloads"
        ex.only_if do
            dpkg = `dpkg -s rstudio-server`
            need_install = dpkg.empty?
            unless need_install
                installed_version = dpkg.split("\n").find{|i| i=~ /^Version/}.split(" ").last
                need_install = (installed_version != version)
            end
            need_install
        end
        ex.run_action :run

    end
    action :create
end


# remote_file "/downloads/#{debfile}" do
#     source url
# end

# dpkg = `dpkg -s rstudio-server`
# need_install = dpkg.empty?
# unless need_install
#     installed_version = dpkg.split("\n").find{|i| i=~ /^Version/}.split(" ").last
#     need_install = (installed_version != version)
# end

# execute "install rstudio-server" do
#     command "gdebi -n #{debfile}"
#     user "root"
#     cwd "/downloads"
#     only_if {need_install}
# end





if on_ec2
    execute "disable password lock in cloud.cfg" do
        command %Q(sed -i.bak "s/lock_passwd: True/lock_passwd: False/" cloud.cfg)
        user "root"   
        cwd "/etc/cloud"     
        not_if "grep -q 'lock_passwd: False' /etc/cloud/cloud.cfg"
    end
end

user username do
    action :modify
    password "bioc"
end

# ^^ that apparently does not always work (even though)
# there is no indication in the log that it isn't working
# so try this:

execute "change password again" do
    user "root"
    command "echo #{username}:bioc | /usr/sbin/chpasswd"
    # always....
end


%w(.Rhistory, .bash_history).each do |file|
    file "/home/#{username}/#{file}" do
        action :delete
    end
end

# FIXME make sure a user-accessible ruby is installed

#sed -i.bak '/\/usr\/lib\/rstudio-server\/bin\/rsession\* ux/a      /usr/local/bin/tryit.sh* ux,' rstudio-server


if on_ec2

    # directory "/usr/lib/rstudio-server/rss-writable" do
    #     action :create
    #     owner "rstudio-server"
    #     group "rstudio-server"
    #     mode "0755"
    # end

    # execute "set up rserver.conf file" do
    #     command "echo 'rsession-path=/usr/local/bin/setup_r_mpi.sh' > rserver.conf"
    #     cwd "/etc/rstudio"
    #     user "root"
    #     not_if {File.exists? "/etc/rstudio/rserver.conf"}
    # end

    ["setup_r_mpi.sh", "restart-rss.sh"].each do |file|

        file "/usr/local/bin/#{file}" do
            action :delete
        end

        remote_file "/usr/local/bin/#{file}" do
            owner "root"
            group "root"
            mode "0755"
            source "file:///vagrant/#{file}"
            action :create_if_missing
        end
    end

    # s2r = "/usr/lib/rstudio-server/bin/rsession/* ux"
    # s2a = "     /usr/local/bin/setup_r_mpi.sh* ux,"
    # execute "modify apparmor config" do
    #     command %Q(mv rstudio-server rstudio-server.old && ruby -pe 'gsub("#{s2r}", "#{s2r}\n#{s2a}")' > rstudio-server && rm rstudio-server.old)
    #     #command %Q(sed -i'' '\/usr\/lib\/rstudio-server\/bin\/rsession\* ux/a \\n     /usr/local/bin/setup_r_mpi.sh* ux,' rstudio-server)
    #     cwd "/etc/apparmor.d"
    #     user "root"
    #     not_if "grep -q setup_r_mpi /etc/apparmor.d/rstudio-server"
    # end

    file "/etc/apparmor.d/rstudio-server" do
        action :delete
    end

    remote_file "/etc/apparmor.d/rstudio-server" do
        owner "root"
        group "root"
        source "file:///vagrant/rstudio-server"
        action :create_if_missing
        mode "0644"
    end


    execute "restart apparmor" do
        command "invoke-rc.d apparmor reload"
        user "root"
    end

    execute "switch rstudio-server to port 80" do
        user "root"
        command "echo 'www-port=80' > /etc/rstudio/rserver.conf"
        not_if "grep -q www-port /etc/rstudio/rserver.conf"
    end

    execute "restart rstudio server" do
        command "rstudio-server restart"
        user "root"
    end

    execute "verify rstudio-server installation" do
        command "rstudio-server verify-installation"
    end


    cron "rstudio_server_config" do
        command "/usr/local/bin/restart-rss.sh >> /var/log/restart-rss.log 2>&1"
        user "root"
        # default is to run every minute
        action :create
    end

    directory "/home/#{username}/.mpi" do
        owner username
        # group username (?)
        action :create
    end

    [".BatchJobs.R", "simple.tmpl"].each do |file|
        remote_file "/home/#{username}/.mpi/#{file}" do
            owner username
            source "file:///vagrant/#{file}"
            mode "0644"
        end
    end
end

remote_file "/usr/local/bin/clean_ami" do
    action :create_if_missing
    owner "root"
    group "root"
    mode "0755"
    source "file:///vagrant/clean_ami"
end



remote_file "/etc/update-motd.d/999-bioc-phone-home" do
    action :create
    owner "root"
    group "root"
    mode "0755"
    source "file:///vagrant/999-bioc-phone-home"
end

remote_file "/home/ubuntu/.Rprofile" do
    action :create
    owner username
    group username
    mode "0755"
    source "file:///vagrant/.Rprofile"
end

remote_file "/etc/init/phone-home.conf" do
    action :create
    owner "root"
    group "root"
    mode "0755"
    source "file:///vagrant/phone-home.conf"
end


package "python-pip" do
    :install
end

execute "install awscli" do
    command "pip install -U awscli"
    not_if "pip list|grep -q awscli"
end

execute "clean_ami" do
    command "/usr/local/bin/clean_ami > /dev/null 2>&1"
    user "root"
end

