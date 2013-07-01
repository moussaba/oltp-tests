require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))

class JobRunBenchmark < SwrJob

  def copy_data?
    copydata = ENV["SWR_COPY_DATA"]
    if copydata != nil
      if copydata == "false"
        return false
      end
    elsif not @config["benchmark"]["do_not_copy_data"] == nil
      if @config["benchmark"]["do_not_copy_data"]
        return false
      end
    end
    return true
  end

  def pre_condition?
    pre_condition = ENV["SWR_PRECONDITION"]
    if pre_condition != nil
      if pre_condition == "false"
        return false
      end
    end
    return true
  end


  def setup(verbose)
    drive = ENV["SWR_DRIVE"]
    shell = SwrShell.new
    puts "------kill off stuff-----"
    kill_all(verbose,true)
    puts "------umount-------------"
    @fileutils.sync verbose
    shell.execute("sudo umount #{drive}",true,status_can_be_nonzero=true)
    cmd = "sudo umount " + config["mysql"]["named_args"]["datadir"]
    shell.execute(cmd,true,status_can_be_nonzero=true)
    if pre_condition?
      puts "-----Pre Conditionning Drive with Sequential Fill -----------"
      cmd = "sudo dd if=/dev/zero of=#{drive} bs=1M count=10"
      shell.execute(cmd,true,status_can_be_nonzero=true)
    end

    if copy_data? || pre_condition?
      puts "------clean up-----------"
      @fileutils.su_rm_rf @config["mysql"]["named_args"]["datadir"], verbose
      @fileutils.su_rm_rf @config["mysql"]["named_args"]["innodb_log_group_home_dir"], verbose
      puts "-----Making File System---------"
      shell.execute("sudo mkfs.ext4 -F #{drive}",true)
      puts "------mkdirs-------------"
      if not file_exists?(@config["mysql"]["named_args"]["datadir"])
        @fileutils.su_mkdir_p @config["mysql"]["named_args"]["datadir"], verbose
      end
      if not file_exists?(@config["mysql"]["named_args"]["innodb_log_group_home_dir"])
        @fileutils.su_mkdir_p @config["mysql"]["named_args"]["innodb_log_group_home_dir"], verbose
      end
      puts "------mount--------------"
      @fileutils.su_mount drive + " -o nobarrier " + config["mysql"]["named_args"]["datadir"]
      puts "------cp data-------------"
      copy_data
      #cmd = "sudo tar -C " + @config["mysql"]["named_args"]["datadir"] "/backup_data/" \
      #                     + ENV["SWR_TEST"] + "/data.tar.gz"
      #shell.execute(cmd,true)
      #cmd = "sudo tar -C " + @config["mysql"]["named_args"]["datadir"] "/backup_data/" + ENV["SWR_TEST"] + "/log.tar.gz"
      #shell.execute(cmd,true)
    else
     puts "------mount--------------"
     @fileutils.su_mount drive + " -o nobarrier " + config["mysql"]["named_args"]["datadir"]
    end

    # Setup benchmark time
  end


  def copy_data
      shell = SwrShell.new
      dirloc = "/backup_data/mysql/" + ENV["SWR_TEST"]
      filename = dirloc + "/data.tar.gz"
      datadir = @config["mysql"]["named_args"]["datadir"]

      if File.file?(filename)
          cmd = "sudo tar -C " + datadir + " -xzf #{filename}"
          shell.execute(cmd,true)
          cmd = "sudo tar -C " + datadir + " -xzf #{dirloc}" + "/log.tar.gz"
          shell.execute(cmd,true)
      else
          cmd = "sudo cp -R " + dirloc + "/* " + datadir
          shell.execute(cmd,true)
      end

  end


  def teardown(verbose)
    puts "------turn off caching solution-------------"
    @solution.stop(verbose)
    puts "------umount----------"
    @drives.umount(verbose,true)
  end

  def start_mysql(buffer_pool_size,verbose)
    puts "------starting mysqld with buffer_pool_size=#{buffer_pool_size}------------"
    @mysqld = SwrMysqld.new(@config["mysql"])
    #@mysqld.args["named_args"]["innodb_buffer_pool_size"] = buffer_pool_size
    @mysqld.start(verbose)
    sleep 60
    puts "------starting benchmark------------"
    @config["benchmark"]["run_time"] = ENV["SWR_RUNTIME"]
    @benchmark = @benchmarks.get_new(@config["benchmark"],@mysqld)
    @benchmark.set_benchmark_run_time
    puts "------making benchmark------------"
    @benchmark.make(verbose)
    puts "------warming up mysqld------------"
    @benchmark.warmup(verbose)
  end

  def shutdown_mysql(verbose)
    @mysqld.innodb_stats(verbose)
    @mysqld.shutdown(verbose)
    puts "-mysql had this to say ----------------"
    stdout, stderr, status, cmd = @mysqld.wait
    puts "cmd[#{cmd}]"
    puts "stdout[#{stdout.chomp}]"
    puts "stderr[#{stderr.chomp}]"
    puts "status[" + status.to_s + "]"
  end

  def doit(verbose)
      buffer_pool_size = @config["mysql"]["innodb_buffer_pool_size"]
      start_mysql(buffer_pool_size,verbose)
      @benchmark.start(verbose)
      shutdown_mysql(verbose)
  end

end

j = SwrDriveInfo.new
j.print
verbose = true
configs = Array.new
configs << "config/mysql/mysql_percona.yaml"
configs << "config/scenario/24G_1trial_1800.yaml"

case ENV["SWR_TEST"]
    when "sysbench"
	configs << "config/benchmark/sysbench_10M_interval.yaml"
    when "sysbench-readonly"
	configs << "config/benchmark/sysbench_10M_readonly_interval.yaml"
    when "tpcc"
	configs << "config/benchmark/tpcc_2500.yaml"
end
#if ENV["SWR_TEST"] == "sysbench"
#else
#  configs << "config/benchmark/tpcc_2500.yaml"
#end

job = JobRunBenchmark.new(configs)

job.setup(verbose)
job.doit(verbose)
#job.teardown(verbose)

j.print
