require File.expand_path(File.join(File.dirname(__FILE__),'swr_benchmark_template.rb'))
require 'timeout'

class SwrSysbench < SwrBenchmarkTemplate

  def update_args
    @args["kill_all"] = ["mysql", "sysbench"]
  end

  def set_benchmark_warmup_time
    @args["named_args"]["max-time"] = @args["warm_up_time"]
  end

  def set_benchmark_run_time
    @args["named_args"]["max-time"] = @args["run_time"]
  end

  def warmup(verbose=false)
    sleep 10
    cmd = "mysql -u root #{@socket_arg} -e \"select avg(id) from sbtest1;\" #{@mysql.dbname}"

    return timeout_run(cmd,verbose,20000)
  end

  def create(verbose=false)
    sleep 10
    cmd = "mysql -u root #{@socket_arg} -e \"create database sbtest;\""
    return timeout_run(cmd,verbose)
  end

end
