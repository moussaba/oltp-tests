require 'rubygems'
require 'json'
require 'rest_client'

class StringIO
  def original_filename
    return File.join("foo.json")
  end
  def content_type
     return 'application/octet-stream'
  end
end


class JenkinsJobs
  def initialize(jhost)
    @jhost = jhost
  end

  def format_parameter(name,value)
    s = "     {\"name\": \"#{name}\", \"value\": \"#{value}\"},\n"
    return s
  end

  def custom_json(parameters)
    s = "{ parameter:\n"
    s += "[\n"
    parameters.each do |name,value|
      s += format_parameter(name,value)
    end
    s += "], \n"
    s += "\"\" : \"\"}"
  end

  def queue_job(job,parameters)
    url = @jhost + "job/" + job + "/build"
    puts "<<========== queue_job - json ===============================>>"
    puts custom_json(parameters)
    puts "<<========== queue_job - url +===============================>>"
    puts url
    puts "<<========== queue_job - resp ===============================>>"
    response = RestClient.post(url, :token => "zorn", :json => custom_json(parameters))
    puts response
  end
end

class JenkinsRunBenchmarks < JenkinsJobs
  def initialize(jhost)
    super(jhost)
    @build_number = 0
  end

  def default_parameters(node)
    parameters = Hash.new
    parameters["MY_BUILD_NUMBER"] = @build_number
    parameters["SLAVE_NAME"] = node
    return parameters
  end

  def queue_fio_job(node,config)
    parameters = Hash.new
    parameters["MY_BUILD_NUMBER"] = @build_number
    parameters["SLAVE_NAME"] = node
    parameters["DRIVE_TO_BASELINE"] = config["DRIVE_TO_BASELINE"]
    parameters["FIO_CONFIGFILE"] = "config/fio/condition.yaml"
    queue_job("fio_job",parameters)
  end

  def set_param(parameters,config,param)
    parameters[param] = config[param]
  end

  def queue_run_benchmark(node,config)
    parameters = Hash.new
    parameters["SLAVE_NAME"] = node
    a = ["SWR_CONFIGFILE_1_MYSQL","SWR_CONFIGFILE_2_BENCHMARK","SWR_CONFIGFILE_3_SCENARIO","SWR_CONFIGFILE_4_SOLUTION","SWR_CONFIGFILE_5_DRIVE","RUN_NAME"]
    a.each { |param| set_param(parameters,config,param) }
    queue_job("run_benchmark",parameters)
  end

  def queue_benchmark(node,config)
    @build_number += 1
    sleep 5
    queue_job("reboot_slave",default_parameters(node))
    sleep 5
    queue_job("thirtyseconds",default_parameters(node))
    sleep 5
    queue_fio_job(node,config)
    sleep 5
    queue_run_benchmark(node,config)
  end
end

jhost = "http://thundarr04.micron.com:8080/"
#jhost = "http://localhost:8088/"


jj = JenkinsRunBenchmarks.new(jhost)

config = Hash.new
config["DRIVE_TO_BASELINE"] = "/dev/rssda"
config["SWR_CONFIGFILE_1_MYSQL"] = "mysql/mysql_001.yaml"
config["SWR_CONFIGFILE_2_BENCHMARK"] = "benchmark/tpcc_1000.yaml"
config["SWR_CONFIGFILE_3_SCENARIO"] = "scenario/24G_1trial_10800.yaml"
config["SWR_CONFIGFILE_4_SOLUTION"] = "solution/empty.yaml"

#wiggins tpcc
config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_p320_m4.yaml"
config["RUN_NAME"] = "wiggins tpcc p320"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_m4_p320.yaml"
config["RUN_NAME"] = "wiggins tpcc m4"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_p320_p320.yaml"
config["RUN_NAME"] = "wiggins tpcc p320 p320"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_2_BENCHMARK"] = "benchmark/sysbench_400M.yaml"
config["SWR_CONFIGFILE_3_SCENARIO"] = "scenario/24G_5trial_600_300.yaml"
config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_p320_m4.yaml"

#wiggins sysbench
config["RUN_NAME"] = "wiggins sysbench p320"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_m4_p320.yaml"
config["RUN_NAME"] = "wiggins sysbench m4"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_p320_p320.yaml"
config["RUN_NAME"] = "wiggins sysbench p320 p320"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_2_BENCHMARK"] = "benchmark/tpce_10k.yaml"
config["SWR_CONFIGFILE_3_SCENARIO"] = "scenario/24G_1trial_10800.yaml"

#wiggins tpce
config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_p320_m4.yaml"
config["RUN_NAME"] = "wiggins tpce p320"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_m4_p320.yaml"
config["RUN_NAME"] = "wiggins tpce m4"
jj.queue_benchmark("Locke",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/locke_p320_p320.yaml"
config["RUN_NAME"] = "wiggins tpce p320 p320"
jj.queue_benchmark("Locke",config)



config["SWR_CONFIGFILE_2_BENCHMARK"] = "benchmark/tpcc_1000.yaml"
config["SWR_CONFIGFILE_3_SCENARIO"] = "scenario/24G_1trial_10800.yaml"
config["SWR_CONFIGFILE_4_SOLUTION"] = "solution/empty.yaml"

#ookla tpcc
config["SWR_CONFIGFILE_5_DRIVE"] = "drive/ookla02_lsi_m4.yaml"
config["RUN_NAME"] = "ookla tpcc lsi"
jj.queue_benchmark("ookla02",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/ookla02_m4_p320.yaml"
config["RUN_NAME"] = "ookla tpcc m4"
jj.queue_benchmark("ookla02",config)

#ookla tpce
config["SWR_CONFIGFILE_2_BENCHMARK"] = "benchmark/tpce_10k.yaml"
config["SWR_CONFIGFILE_4_SOLUTION"] = "solution/empty.yaml"
config["SWR_CONFIGFILE_5_DRIVE"] = "drive/ookla02_p320_m4.yaml"
config["RUN_NAME"] = "ookla tpce p320"
jj.queue_benchmark("ookla02",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/ookla02_lsi_m4.yaml"
config["RUN_NAME"] = "ookla tpce lsi"
jj.queue_benchmark("ookla02",config)

config["SWR_CONFIGFILE_5_DRIVE"] = "drive/ookla02_m4_p320.yaml"
config["RUN_NAME"] = "ookla tpce m4"
jj.queue_benchmark("ookla02",config)

config["SWR_CONFIGFILE_4_SOLUTION"] = "solution/velobit_4G_0s_p320.yaml"
config["SWR_CONFIGFILE_5_DRIVE"] = "drive/ookla02_lsi_m4.yaml"
config["RUN_NAME"] = "ookla tpce velobit"
jj.queue_benchmark("ookla02",config)

config["SWR_CONFIGFILE_4_SOLUTION"] = "solution/vfcache_p320.yaml"
config["RUN_NAME"] = "ookla tpce vfcache"
jj.queue_benchmark("ookla02",config)

config["SWR_CONFIGFILE_4_SOLUTION"] = "solution/flashcache_thru_p320.yaml"
config["RUN_NAME"] = "ookla tpce flashcache"
jj.queue_benchmark("ookla02",config)

