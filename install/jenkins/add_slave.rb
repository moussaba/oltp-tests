require 'optparse'
require 'rubygems'
require 'jenkins_api_client'
require File.join(File.dirname(__FILE__),'..','common','swr_common.rb')

ip = ""
user = "jenkins"
password = "123456"
slave = ""
slavename = ""

op = OptionParser.new { |opts|
  
  opts.banner = "Usage: #{File.basename($0)} --jenkins swr-jenkins.micron.com --slave 10.102.215.15 --slavename mazer [--user jenkins --password 123456]"

  opts.on('-j', '--jenkins HOSTNAME', 'Hostname or IP address of your jenkins server') do |arg|
    ip = arg
  end

  opts.on('-s', '--slave HOSTNAME', 'Hostname or IP address of the slave to add') do |arg|
    slave = arg
  end

  opts.on('-n', '--slavename NAME', 'Name of the slave to add') do |arg|
    slavename = arg
  end

  opts.on('-u', '--user USERNAME', 'jenkins username with permissions to add') do |arg|
    user = arg
  end

  opts.on('-p', '--password PASSWORD', 'jenkins users password') do |arg|
    password = arg
  end

}

op.parse!
if ip.length < 2 or user.length < 2 or password.length < 2 or slave.length < 2 or slavename.length < 2
  puts op.banner
  raise
end

def run_remote(ssh_handle,cmd)
  stdout, stderr, status = ssh_handle.execute(cmd,true)
  if status != 0
    puts "----------------------"
    puts "stdout[#{stdout.chomp}]"
    puts "stderr[#{stderr.chomp}]"
    puts "status[" + status.to_s + "]"
    puts "----------------------"
    raise
  end
  return stdout, stderr
end

s = SwrSsh.new(slave, user, password)
j = SwrSsh.new(ip, user, password)

run_remote(s,"mkdir -p /home/#{user}/.ssh")
stdout, stderr = run_remote(j,"cat /home/#{user}/.ssh/id_rsa.pub")
run_remote(s,"echo \"#{stdout}\" > /home/#{user}/.ssh/id_rsa.pub")
stdout, stderr = run_remote(j,"cat /home/#{user}/.ssh/id_rsa")
run_remote(s,"echo \"#{stdout}\" > /home/#{user}/.ssh/id_rsa")
run_remote(s,"cat /home/#{user}/.ssh/id_rsa.pub > /home/#{user}/.ssh/authorized_keys")
run_remote(s,"chmod 700 /home/#{user}/.ssh")
run_remote(s,"chmod 640 /home/#{user}/.ssh/authorized_keys")
run_remote(s,"chown -R #{user}:#{user} /home/#{user}/.ssh")

client = JenkinsApi::Client.new(:server_ip => ip,:username => user,:password => password)

params = {}
params[:name] = slavename
params[:slave_host] = slave
params[:private_key_file] = ""
params[:slave_user] = ""
params[:description] = ""
params[:remote_fs] = "/home/#{user}"
params[:executors] = 1

puts client.node.create_dump_slave(params)
