require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))

class JobRunSysbench < SwrJob

  def file_exists?(file)
    if File.exists?(file) or File.symlink?(file)
      return true
    end
    return false
  end

  def setup(verbose)
    puts "------kill off mysqlds----------"
    @mysqld = SwrMysqld.new(@config["mysql"])
    @mysqld.kill_all_existing(verbose)
    sleep 5
    puts "------umount----------"
    @fileutils.sync verbose
    @drives.umount(verbose,true)
    puts "------partition----------"
    @drives.partition(verbose)
    puts "------format-------------"
    @drives.format(verbose)
    puts "------mount--------------"
    @drives.mount(verbose)
    puts "------mkdirs-------------"
    if not file_exists?(@config["mysql"]["named_args"]["datadir"])
      @fileutils.su_mkdir_p @config["mysql"]["named_args"]["datadir"], verbose
    end
    if not file_exists?(@config["mysql"]["named_args"]["innodb_log_group_home_dir"])
      @fileutils.su_mkdir_p @config["mysql"]["named_args"]["innodb_log_group_home_dir"], verbose
    end
    puts "------cp data-------------"
    @drives.copy_data(verbose)
  end

  def start_velobit(verbose)
    cmd  = "sudo velobit start"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def stop_velobit(verbose)
    cmd  = "sudo velobit stop"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def teardown(verbose)
    puts "------umount----------"
    @drives.umount(verbose)
  end

  def start_mysql(buffer_pool_size,verbose)
    puts "------starting mysqld with buffer_pool_size=#{buffer_pool_size}------------"
    @mysqld.args["named_args"]["innodb_buffer_pool_size"] = buffer_pool_size
    @mysqld.start(verbose)
    sleep 60
    puts "------warming up mysqld------------"
    @sysbench = SwrSysbench.new(@config["sysbench"],@mysqld)
    @sysbench.warmup(verbose)
  end

  def warmup_sysbench(verbose)
    puts "------warming up sysbench------------"
    max_time = @sysbench.args["named_args"]["max-time"]
    @sysbench.args["named_args"]["max-time"] = @config["sysbench"]["warm_up_time"]
    @sysbench.start(verbose)
    @sysbench.args["named_args"]["max-time"] = max_time
  end

  def shutdown_mysql(verbose)
    @mysqld.shutdown(verbose)
    puts "-mysql had this to say ----------------"
    stdout, stderr, status, cmd = @mysqld.wait
    puts "cmd[#{cmd}]"
    puts "stdout[#{stdout.chomp}]"
    puts "stderr[#{stderr.chomp}]"
    puts "status[" + status.to_s + "]"
  end

  def doit(verbose)
    @config["mysqld_buffer_sizes"].each do |buffer_pool_size|
      start_mysql(buffer_pool_size,verbose)
      warmup_sysbench(verbose)
      @config["sysbench_trials"].times do |i|
        puts "------running sysbench trial #{(i+1).to_s}------------"
        @sysbench.start(verbose)
      end
      shutdown_mysql(verbose)
    end
  end

end

j = SwrDriveInfo.new
j.print
verbose = true
job = JobRunSysbench.new(ARGV[0])
job.setup(verbose)
if job.config["velobit"] != nil
  job.start_velobit(verbose)
end
job.doit(verbose)
job.teardown(verbose)
if job.config["velobit"] != nil
  job.stop_velobit(verbose)
end
j.print