require 'optparse'
require 'rubygems'
require 'jenkins_api_client'

ip = ""
user = ""
password = ""
slave = ""
slavename = ""

op = OptionParser.new { |opts|
  
  opts.banner = "Usage: #{File.basename($0)} -u -i -s filename"

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

client = JenkinsApi::Client.new(:server_ip => ip,:username => user,:password => password)

params = {}
params[:name] = slavename
params[:slave_host] = slave
params[:private_key_file] = ""
params[:slave_user] = ""
params[:description] = ""
params[:remote_fs] = "/home/jenkins"
params[:executors] = 1

puts client.node.create_dump_slave(params)
