require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_jruby_registers.rb'))

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

  def setup(verbose)
    puts "------kill off stuff-----"
    kill_all(verbose,true)
    puts "------umount-------------"
    @fileutils.sync verbose
    @drives.umount(verbose,true)
    if copy_data?
      puts "------clean up-----------"
      @fileutils.su_rm_rf @config["mysql"]["named_args"]["datadir"], verbose
      @fileutils.su_rm_rf @config["mysql"]["named_args"]["innodb_log_group_home_dir"], verbose
      puts "------partition----------"
      @drives.partition(verbose)
      puts "------format-------------"
      @drives.format(verbose)
    end
    puts "------mount--------------"
    @drives.mount(verbose)
    if copy_data?
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
    puts "------turn on caching solution-------------"
    @solution = @solutions.get_new(@config["solution"],@config)
    @solution.configure(verbose)
    @solution.start(verbose)
    puts "------set up register configuration--------"
    @registers = JRubyRegisters.new(@config["registers"]["drive_address"])
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
    @mysqld.args["named_args"]["innodb_buffer_pool_size"] = buffer_pool_size
    @mysqld.start(verbose)
    sleep 60
    puts "------starting benchmark------------"
    @benchmark = @benchmarks.get_new(@config["benchmark"],@mysqld)
    puts "------making benchmark------------"
    @benchmark.make(verbose)
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
    #@mysqld.innodb_stats(verbose)
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
      # start_mysql(buffer_pool_size,verbose)
      # warmup_benchmark(verbose)
      # #put drive in a safe state for changing registers
      # shutdown_mysql(verbose)
      #@benchmark.set_benchmark_run_time
      @drives.umount()
      @registers.unlock_registers()

      #this is different from standard run_benchmark - iterations are set by "register_trials" instead of "trials"
      @config["registers"]["register_trials"].times do |i|
        puts ">>>---running benchmark trial #{(i+1).to_s}------------"
        puts ">>>---setting register #{@config["registers"]["settings"][i]["address"]} to #{@config["registers"]["settings"][i]["new_value"]}"
        
        #copy off the current setting
        @saved_value = @registers.get_register(@config["registers"]["settings"][i]["address"])
        @saved_value = @saved_value.chop!

        #write in the new setting
        @registers.set_register(@config["registers"]["settings"][i]["address"],@config["registers"]["settings"][i]["new_value"])
        puts "register is now set to #{@registers.get_register(@config["registers"]["settings"][i]["address"])}"
        
        @drives.mount()
        start_mysql(buffer_pool_size,verbose)
        warmup_benchmark(verbose)
        @benchmark.start(verbose)
        #@benchmark.set_benchmark_run_time
        
        #put the drive into a safe state for changing registers
        shutdown_mysql(verbose)
        @drives.umount()
        
        #restore the registers to their original setting
        @registers.set_register(@config["registers"]["settings"][i]["address"],@saved_value)
        puts "register #{@config["registers"]["settings"][i]["address"]} has been restored to #{@registers.get_register(@config["registers"]["settings"][i]["address"])}"
      end
      @registers.lock_registers()
      #shutdown_mysql(verbose)
    end
  end
end

j = SwrDriveInfo.new
j.print
verbose = true
job = JobRunBenchmark.new(ARGV)
job.setup(verbose)
job.doit(verbose)
job.teardown(verbose)

j.print
