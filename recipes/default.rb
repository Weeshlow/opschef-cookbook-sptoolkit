#
# Cookbook Name:: sptoolkit
# Recipe:: default
#
# Copyright 2012, Marshall University
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

# Include required recipes
include_recipe "mysql::server"
include_recipe "apache2::mod_php5"

# Download software
cookbook_file "/tmp/sptoolkit_0.42.zip" do
  mode 0755
  owner "root"
  group "root"
  source "sptoolkit_0.42.zip"
end

# Unzip sptoolkit to www_root_dir
script "install_sptoolkit" do
  interpreter "bash"
  user "root"
  cwd "/tmp"
  code <<-EOH
  unzip /tmp/sptoolkit_0.42.zip -d #{node['sptoolkit']['www_root_dir']}
  rm -f /tmp/sptoolkit_0.42.zip 
  EOH
  not_if "test -d #{node['sptoolkit']['www_root_dir']}/spt"
end

# Set permissions on #{node[:sptoolkit][:www_root_dir]}/spt
case node["platform_family"]
  when "rhel"
    %w{ php53-mysql }.each do |pkg|
     package pkg
    end
    script "set_spt_permissions" do
    interpreter "bash"
    user "root"
    cwd node['sptoolkit']['www_root_dir']
    code <<-EOH
    chown apache:apache -R #{node['sptoolkit']['www_root_dir']}/spt
    EOH
    not_if "ls -al #{node['sptoolkit']['www_root_dir']}/spt |grep apache"
    end

  when "debian"
    %w{ php5-mysql }.each do |pkg|
     package pkg
    end
    script "set_spt_permissions" do
    interpreter "bash"
    user "root"
    cwd node['sptoolkit']['www_root_dir']
    code <<-EOH
    chown www-data:www-data -R #{node['sptoolkit']['www_root_dir']}/spt
    EOH
    not_if "ls -al #{node['sptoolkit']['www_root_dir']}/spt |grep www-data"
    end
end

# Generate random password, assign to db user spt
# and write password to /etc/spt_db_pass.conf.
ruby_block "gen_rand_spt_db_pass" do
  block do
    def newpass( len )

      chars = ("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a
      newpass = ""
      1.upto(len) { |i| newpass << chars[rand(chars.size)] }
      return newpass

    end

    pass = newpass(10)
    node['sptoolkit']['db_pass'] = pass

    # Write random password to file
    f = File.new( "/etc/spt_db_pass.conf", "w" )
    f.puts( "This is db username & password for the Simple Phish Toolkit.\n" )
    f.puts( "Generated by Opscode Chef!\n" )
    f.puts( "SPT Database Name: #{node['sptoolkit']['db_name']}" )
    f.puts( "SPT Database User: #{node['sptoolkit']['db_user']}" )
    f.puts( "SPT Database Password: #{node['sptoolkit']['db_pass']}" )
    f.close

    # Create Simple Phish Toolkit MySQL Database
    system( "/usr/bin/mysql -u root --password='#{node['mysql']['server_root_password']}' --execute='CREATE DATABASE #{node['sptoolkit']['db_name']}'" )
    system( "/usr/bin/mysql -u root --password='#{node['mysql']['server_root_password']}' --execute='GRANT ALL PRIVILEGES ON *.* TO #{node['sptoolkit']['db_user']}@localhost'" )
    system( "/usr/bin/mysql -u root --password='#{node['mysql']['server_root_password']}' --execute='SET PASSWORD FOR #{node['sptoolkit']['db_user']}@localhost = PASSWORD('#{node['sptoolkit']['db_pass']}')'" )
    system( "/usr/bin/mysql -u root --password='#{node['mysql']['server_root_password']}' --execute='FLUSH PRIVILEGES'" )

  end
  action :create
  not_if "test -e /etc/spt_db_pass.conf"
end
