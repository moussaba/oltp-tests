require File.expand_path(File.join(File.dirname(__FILE__),'swr_benchmark_template.rb'))
require 'timeout'

class SwrSysbench < SwrBenchmarkTemplate

  def update_args
    @args["kill_all"] = ["mysql", "sysbench"]
  end

  def set_benchmark_warmup_time(warm_up_time)
    @args["named_args"]["max-time"] = warm_up_time
  end

  def set_benchmark_run_time(run_time)
    @args["named_args"]["max-time"] = run_time
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

  def set_parameters(config)
    rows = config['env']["SWR_MILLIONS_OF_ROWS"]
    tables = config['env']["SWR_NUMBER_OF_TABLES"]
    config["benchmark"]["named_args"]["oltp-table-size"] = 1000000 * rows.to_i
    config["benchmark"]["named_args"]["oltp_tables_count"] = tables.to_i
    config["tar_data"] += rows.to_s + "M"+"_ROWS_" + tables.to_s+"_TABLES"
  end

end
