require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))

class JobRunVelobitBenchmarks  < SwrJob
  def iterate_ram_sizes(verbose)
    ram_sizes = @config["solution"]["named_args"]["ram_sizes"]
    ram_sizes.each do |size|
      set_reserved_memory(size)
      setup(verbose)
      doit(verbose)
      teardown(verbose)
    end
  end

  def iterate_cache_depths(verbose)
    cache_depths = @config["solution"]["named_args"]["write_cache_depths"]
    cache_depths.each do |depth|
      set_cache_depth(depth)
      setup(verbose)
      doit(verbose)
      teardown(verbose)
    end
  end

  def set_reserved_memory(reserved_memory)
    @config["solution"]["named_args"]["reserved_memory"] = reserved_memory
  end
  
  def set_cache_depth(write_cache_depth)
    @config["solution"]["named_args"]["write_cache_depth"] = write_cache_depth
  end

  def setup(verbose)
    puts "------kill off stuff-----"
    kill_all(verbose,true)
    puts "------umount-------------"
    @fileutils.sync verbose
    @drives.umount(verbose,true)
    puts "------clean up-----------"
    @fileutils.su_rm_rf @config["mysql"]["named_args"]["datadir"], verbose
    @fileutils.su_rm_rf @config["mysql"]["named_args"]["innodb_log_group_home_dir"], verbose
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
    @solution = @solutions.get_new(@config["solution"],@config)
    @solution.configure(verbose)
    @solution.start(verbose)
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

puts "inside run velobit benchmarks"
j = SwrDriveInfo.new
j.print
verbose = true
puts "starting new velobit benchmarks"
job = JobRunVelobitBenchmarks.new(ARGV)
iteration = ENV['ITERATION']
case iteration
when "ram"
  puts "iterating through ram sizes"
  job.iterate_ram_sizes(verbose)
when "depth"
  puts "iterating through write cache depths"
  job.iterate_cache_depths(verbose)
else
  job.setup(verbose)
  job.doit(verbose)
  job.teardown(verbose)
end
j.print