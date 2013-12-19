# ensure Jenkins has Node and Label parameter plugin installed
require 'jenkins_api_client'

ip = 'swr-jenkins.micron.com'
user = 'jenkins'
pass = '123456'

client = JenkinsApi::Client.new(:server_ip => ip,:username => user,:password => pass)


drive = "/dev/rssda"
runtime = "600"
slave = "mazer"

oltp_params = Hash.new
oltp_params['SWR_DRIVE'] = drive
oltp_params['SWR_RUNTIME'] = runtime
oltp_params['SWR_COPY_DATA'] = true
oltp_params['SWR_PRECONDITION'] = false
oltp_params['SLAVE_NAME'] = slave


bnum = Time.now.to_i.to_s
client.job.build("reboot_slave",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
client.job.build("thirtyseconds",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
oltp_params['RUN_NAME'] = "first sysbench run"
client.job.build("benchmark_oltp--sysbench",oltp_params)
sleep 2

bnum = Time.now.to_i.to_s
client.job.build("reboot_slave",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
client.job.build("thirtyseconds",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
oltp_params['RUN_NAME'] = "second -nocopy- sysbench run"
oltp_params['SWR_COPY_DATA'] = false
client.job.build("benchmark_oltp--sysbench",oltp_params)
sleep 2

bnum = Time.now.to_i.to_s
client.job.build("reboot_slave",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
client.job.build("thirtyseconds",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
oltp_params['RUN_NAME'] = "first sysbench-readonly run"
oltp_params['SWR_COPY_DATA'] = true
client.job.build("benchmark_oltp--sybench-readonly",oltp_params)
sleep 2

bnum = Time.now.to_i.to_s
client.job.build("reboot_slave",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
client.job.build("thirtyseconds",{"SLAVE_NAME" => slave, "MY_BUILD_NUMBER" => bnum })
sleep 2
oltp_params['RUN_NAME'] = "first tpcc run"
client.job.build("benchmark_oltp--tpcc",oltp_params)

