# ensure Jenkins has Node and Label parameter plugin installed
require 'optparse'
require 'rubygems'
require 'jenkins_api_client'
require File.join(File.dirname(__FILE__),'..','common','swr_common.rb')

ip = ""
user = "jenkins"
password = "123456"

op = OptionParser.new { |opts|
  
  opts.banner = "Usage: #{File.basename($0)} --jenkins swr-jenkins.micron.com [--user jenkins --password 123456]"

  opts.on('-j', '--jenkins HOSTNAME', 'Hostname or IP address of your jenkins server') do |arg|
    ip = arg
  end

  opts.on('-u', '--user USERNAME', 'jenkins username with permissions to add') do |arg|
    user = arg
  end

  opts.on('-p', '--password PASSWORD', 'jenkins users password') do |arg|
    password = arg
  end

}

op.parse!
if ip.length < 2 or user.length < 2 or password.length < 2
  puts op.banner
  raise
end

client = JenkinsApi::Client.new(:server_ip => ip,:username => user,:password => pass)


["create_sysbench_data",\
"create_tpcc_data",\
"thirtyseconds",\
"benchmark_oltp--sysbench-readonly",\
"benchmark_oltp--sysbench",\
"benchmark_oltp--tpcc",\
"reboot_slave"].each do |jobname|
  puts client.job.create(jobname,File.read("xmls/"+jobname+"-config.xml"))
end
