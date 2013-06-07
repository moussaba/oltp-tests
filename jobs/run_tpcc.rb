require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))

class JobRunTpcc < SwrJob

  def setup(verbose)
    puts "------kill off stuff----------"
    kill_all(verbose,true)
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
    puts "------turn on caching solution-------------"
    @solution = @solutions.get_new(@config["solution"])
    @solution.start(verbose)
  end

  def teardown(verbose)
    puts "------turn off caching solution-------------"
    @solution.stop(verbose)
    puts "------umount----------"
    @drives.umount(verbose)
  end

  def start_mysql(buffer_pool_size,verbose)
    puts "------starting mysqld with buffer_pool_size=#{buffer_pool_size}------------"
    @mysqld = SwrMysqld.new(@config["mysql"])
    @mysqld.args["named_args"]["innodb_buffer_pool_size"] = buffer_pool_size
    @mysqld.start(verbose)
    sleep 60
    puts "------starting benchmark------------"
    @benchmark = @benchmarks.get_new(@config["benchmark"],@mysqld)
    puts "------warming up mysqld------------"
    @benchmark.warmup(verbose)
  end

  def warmup_benchmark(verbose)
    puts "------warming up benchmark------------"
    @benchmark.set_benchmark_warmup_time
    @benchmark.start(verbose)
    @benchmark.set_benchmark_run_time
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
      warmup_benchmark(verbose)
      @config["trials"].times do |i|
        puts "------running benchmark trial #{(i+1).to_s}------------"
        @benchmark.start(verbose)
      end
      shutdown_mysql(verbose)
    end
  end

end

j = SwrDriveInfo.new
j.print
verbose = true
job = JobRunTpcc.new(ARGV[0])
job.setup(verbose)
job.doit(verbose)
job.teardown(verbose)

j.print