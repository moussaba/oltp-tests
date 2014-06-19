require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_mysql_benchmarks.rb'))

class JobRunOltp < SwrJob

  def initialize(args)
    super(args)
    @required_env_vars = ["SWR_DRIVE","SWR_RUNTIME"]
    @optional_env_vars = ["SWR_COPY_DATA","SWR_PRECONDITION","SWR_PORT","SWR_KILLALL"]
    @required_config_sections = ["benchmark","mysql","tar_data"]
    validate_config()
    @datadir = @config["mysql"]["named_args"]["datadir"]
    @logdir = @config["mysql"]["named_args"]["innodb_log_group_home_dir"]
    @drive = @config['env']["SWR_DRIVE"]
    @config["mysql"]["named_args"]["port"] = @config['env']["SWR_PORT"].to_s
    @config["benchmark"]["named_args"]["mysql-port"] = @config['env']["SWR_PORT"].to_s
    @config["benchmark"]["named_args"]["mysql-socket"] = @config["mysql"]["named_args"]["socket"]
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

  def kill_all?
    killall = @config['env']["SWR_KILLALL"]
    if killall != nil
      if killall == "false"
        return false
      end
    end
    return true
  end

  def setup(verbose)
    shell = SwrShell.new
    if kill_all?
	puts "------kill all-------------" + timestamp
	@benchmarks.kill_all(verbose)
    end
    puts "------umount-------------" + timestamp
    @fileutils.sync verbose
    cmd = "sudo umount " + @drive
    shell.execute(cmd,true,true)
    cmd = "sudo umount " + @datadir
    shell.execute(cmd,true,true)
    if pre_condition?
      puts "-----Pre Conditionning Drive with Sequential Fill -----------" + timestamp
      cmd = "sudo dd if=/dev/zero of=#{@drive} bs=1M"
      shell.execute(cmd,true,true)
    end

    if copy_data? || pre_condition?
      puts "------clean up-----------" + timestamp
      @fileutils.su_rm_rf @datadir, verbose
      @fileutils.su_rm_rf @logdir, verbose
      puts "-----Making File System---------" + timestamp
      shell.execute("sudo mkfs.ext4 -F #{@drive}",true)
    end
    puts "------mkdirs-------------" + timestamp
    if not file_exists?(@datadir)
      @fileutils.su_mkdir_p @datadir, verbose
    end
    if not file_exists?(@logdir)
      @fileutils.su_mkdir_p @logdir, verbose
    end
    puts "------mount--------------" + timestamp
    @fileutils.su_mount @drive + " -o nobarrier " + @datadir
    if copy_data? || pre_condition?
      puts "------cp data-------------" + timestamp
      copy_data(verbose)
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
    do_untar(@datadir,@config['tar_data'],"data",verbose)
    do_untar(@logdir,@config['tar_data'],"log",verbose)
  end

  def teardown(verbose)
    puts "------umount----------" + timestamp
    shell = SwrShell.new
    cmd = "sudo umount " + @drive
    shell.execute(cmd,true,true)
  end

  def start_db(verbose)
    puts "------starting mysqld ------------" + timestamp
    @db = SwrMysqld.new(@config["mysql"])
    @db.start(verbose)
    sleep 60
    puts "------setting up benchmark------------" + timestamp
    @benchmark = @benchmarks.get_new(@config["benchmark"],@db)
    @benchmark.set_benchmark_run_time(@config['env']["SWR_RUNTIME"])
    puts "------making benchmark------------" + timestamp
    @benchmark.make(verbose)
    puts "------warming up mysqld------------" + timestamp
    @benchmark.warmup(verbose)
  end

  def shutdown_db(verbose)
    @db.innodb_stats(verbose)
    @db.shutdown(verbose)
    puts "-mysql had this to say ----------------" + timestamp
    stdout, stderr, status, cmd = @db.wait
    puts "cmd[#{cmd}]"
    puts "stdout[#{stdout.chomp}]"
    puts "stderr[#{stderr.chomp}]"
    puts "status[" + status.to_s + "]"
  end

  def doit(verbose)
    start_db(verbose)
    @benchmark.start(verbose)
    shutdown_db(verbose)
  end

end

j = SwrDriveInfo.new
j.print
verbose = true

job = JobRunOltp.new(ARGV)

puts Time.now.strftime("%Y/%m/%d - %T")
job.setup(verbose)
job.doit(verbose)
job.teardown(verbose)
puts Time.now.strftime("%Y/%m/%d - %T")

j.print
