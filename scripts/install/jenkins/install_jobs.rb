# ensure Jenkins has Node and Label parameter plugin installed
require 'jenkins_api_client'

ip = '10.102.215.213'
user = 'jenkins'
pass = '123456'

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
