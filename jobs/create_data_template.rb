require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_benchmarks.rb'))

class JobCreateDataTemplate < SwrJob

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
  end

  def tar_data(verbose)
    @fileutils.su_mkdir_p @config["tar_data"], verbose
    @fileutils.su_du_sh "#{@config["mysql"]["named_args"]["datadir"]}", verbose
    @fileutils.su_tar " -C #{@config["mysql"]["named_args"]["datadir"]} "," -czf #{File.join(@config["tar_data"],"data.tar.gz")}", ".", verbose
    if @config["mysql"]["named_args"]["datadir"] == @config["mysql"]["named_args"]["innodb_log_group_home_dir"]
      #log and data dirs are the same so creating empty log.tar.gz
      @fileutils.su_mkdir_p "empty", verbose
      @fileutils.su_tar " -C empty "," -czf #{File.join(@config["tar_data"],"log.tar.gz")}",".", verbose
      @fileutils.su_rm_rf "empty", verbose
    else
      @fileutils.su_tar " -C #{@config["mysql"]["named_args"]["innodb_log_group_home_dir"]} "," -czf #{File.join(@config["tar_data"],"log.tar.gz")}",".", verbose
    end
    shell = SwrShell.new
    cmd = "cd #{@config["tar_data"]}; du -h; sudo touch md5sums.txt; sudo chmod a+rw md5sums.txt; sudo md5sum data.tar.gz >> md5sums.txt; sudo md5sum log.tar.gz >> md5sums.txt;"
    shell.execute(cmd,verbose)
    @fileutils.sync verbose
  end

  def teardown(verbose)
    puts "------umount----------"
    @drives.umount(verbose)
  end

  def start_mysql(buffer_pool_size,verbose)
    puts "------starting mysqld with buffer_pool_size=#{buffer_pool_size}------------"
    @mysqld = SwrMysqld.new(@config["mysql"])
    if buffer_pool_size != nil
      @mysqld.args["named_args"]["innodb_buffer_pool_size"] = buffer_pool_size
    end
    @mysqld.start(verbose)
    sleep 60
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
    puts "------initializing mysql db------------"
    shell = SwrShell.new
    cmd = "sudo mysql_install_db --datadir=#{@config["mysql"]["named_args"]["datadir"]}"
    shell.execute(cmd,verbose)
    start_mysql(nil,verbose)
    puts "------starting benchmark------------"
    @benchmark = @benchmarks.get_new(@config["benchmark"],@mysqld)
    @benchmark.make(verbose)
    @benchmark.create(verbose)
    @benchmark.load(verbose)
    shutdown_mysql(verbose)
  end

  def get_jenkins_parameters
  end

end
