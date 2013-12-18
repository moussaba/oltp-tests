require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_mysql_benchmarks.rb'))

class JobMultiMysql < SwrJob

  def initialize(args)
    super(args)
    @required_env_vars = ["SWR_DRIVE","SWR_RUNTIME"]
    @optional_env_vars = ["SWR_COPY_DATA","SWR_PRECONDITION"]
    @required_config_sections = ["benchmark","mysql","tar_data"]
    validate_config()
    @da = Array.new
    @config['mysql'].length.times do |n|
      @da[n] = @config['env']["SWR_DRIVE"] + (n+1).to_s
    end
    @benchmarks = SwrMySqlBenchmarks.new
  end

  def copy_data?
    copydata = @config['env']["SWR_COPY_DATA"]
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
    pre_condition = @config['env']["SWR_PRECONDITION"]
    if pre_condition != nil
      if pre_condition == "false"
        return false
      end
    end
    return true
  end

  def datadir(mysql)
    return mysql["named_args"]["datadir"]
  end

  def logdir(mysql)
    return mysql["named_args"]["innodb_log_group_home_dir"]
  end

  def setup(verbose)
    shell = SwrShell.new
    puts "------kill all-------------" + timestamp
    @benchmarks.kill_all(verbose)
    @config['mysql'].length.times do |n|
      m = @config['mysql'][n]
      drive = @da[n]
      puts "------umount-" + drive + "------------" + timestamp
      @fileutils.sync verbose
      cmd = "sudo umount " + @drive
      shell.execute(cmd,true,true)
      cmd = "sudo umount " + datadir(m)
      shell.execute(cmd,true,true)
      if pre_condition?
        puts "-----Pre Conditionning Drive with Sequential Fill -----------" + timestamp
        cmd = "sudo dd if=/dev/zero of=#{drive} bs=1M"
        shell.execute(cmd,true,true)
      end

      if copy_data? || pre_condition?
        puts "------clean up-----------" + timestamp
        @fileutils.su_rm_rf datadir(m), verbose
        @fileutils.su_rm_rf logdir(m), verbose
        puts "-----Making File System---------" + timestamp
        shell.execute("sudo mkfs.ext4 -F #{drive}",true)
        puts "------mkdirs-------------" + timestamp
        if not file_exists?(datadir(m))
          @fileutils.su_mkdir_p datadir(m), verbose
        end
        if not file_exists?(logdir(m))
          @fileutils.su_mkdir_p logdir(m), verbose
        end
      end
      puts "------mount--------------" + timestamp
      @fileutils.su_mount drive + " -o nobarrier " + datadir(m)
      if copy_data? || pre_condition?
        puts "------cp data-------------" + timestamp
        copy_data(verbose)
      end
    end
  end

  def do_untar(dstdir,srcdir,filename,verbose)
    src = File.join(srcdir,filename + ".tar")
    srcgz = src + ".gz"
    srcbz = src + ".bz2"
    srcsnz = src + ".snz"
    if file_exists?(src)
      @fileutils.su_tar " -C #{dstdir} ", " -xf #{src}", verbose
    elsif file_exists?(srcgz)
      @fileutils.su_tar " -C #{dstdir} ", " -xzf #{srcgz}", verbose
    elsif file_exists?(srcbz)
      @fileutils.su_tar " -C #{dstdir} ", " -xjf #{srcbz}", verbose
    elsif file_exists?(srcsnz)
      shell = SwrShell.new
      cmd = "snzip -dc #{srcsnz} | tar -C #{dstdir} -x"
      shell.su_execute(cmd,verbose)
    else
      raise "not found trolls"
    end
  end

  def copy_data(verbose)
    @config['mysql'].length.times do |n|
      m = @config['mysql'][n]
      do_untar(datadir(m),@config['tar_data'],"data",verbose)
      do_untar(logdir(m),@config['tar_data'],"log",verbose)
    end
  end

  def teardown(verbose)
    @config['mysql'].length.times do |n|
      drive = @da[n]
      puts "------umount----------" + timestamp
      shell = SwrShell.new
      cmd = "sudo umount " + drive
      shell.execute(cmd,true,true)
    end
  end

  def start_db(verbose)
    @config['mysql'].length.times do |n|
      m = @config['mysql'][n]
      drive = @da[n]
      puts "------starting mysqld ------------" + timestamp
      @db[n] = SwrMysqld.new(@config["mysql"])
      @db[n].start(verbose)
      sleep 60
      puts "------setting up benchmark------------" + timestamp
      @benchmark[n] = @benchmarks.get_new(@config["benchmark"],@db[n])
      @benchmark[n].set_benchmark_run_time(@config['env']["SWR_RUNTIME"])
      puts "------making benchmark------------" + timestamp
      @benchmark[n].make(verbose)
      puts "------warming up mysqld------------" + timestamp
      @benchmark[n].warmup(verbose)
    end
  end

  def shutdown_db(verbose)
    @db.each do |db|
      db.innodb_stats(verbose)
      db.shutdown(verbose)
      puts "-mysql had this to say ----------------" + timestamp
      stdout, stderr, status, cmd = @db.wait
      puts "cmd[#{cmd}]"
      puts "stdout[#{stdout.chomp}]"
      puts "stderr[#{stderr.chomp}]"
      puts "status[" + status.to_s + "]"
    end
  end

  def doit(verbose)
    start_db(verbose)
    @benchmark.each do |b|
      benchmark.start(verbose)
    end
    shutdown_db(verbose)
  end

end

j = SwrDriveInfo.new
j.print
verbose = true

job = JobMultiMysql.new(ARGV)

puts Time.now.strftime("%Y/%m/%d - %T")
job.setup(verbose)
job.doit(verbose)
job.teardown(verbose)
puts Time.now.strftime("%Y/%m/%d - %T")

j.print
