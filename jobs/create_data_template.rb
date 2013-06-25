require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_benchmarks.rb'))

class JobCreateDataTemplate < SwrJob

  def initialize(configfiles)
    super(configfiles)
    case ENV["SWR_DB_TYPE"]
      when "mysql"
        @datadir = @config["mysql"]["named_args"]["datadir"]
        @logdir = @config["mysql"]["named_args"]["innodb_log_group_home_dir"]

      when "mongodb"
        @datadir = @config["mongodb"]["named_args"]["dbpath"]
        @logdir = ""
      when "cassandra"
        @datadir = @config["cassandra"]["conf"]["data_file_directories"]
        @logdir = ""

    end
  
    puts "------kill off stuff----------"

  end

  def setup(verbose)
    
    shell = SwrShell.new
    drive = ENV["SWR_DRIVE"]
    kill_all(verbose,true)
    puts "------umount----------"
    @fileutils.sync verbose
    shell.execute("sudo umount #{drive}",true,status_can_be_nonzero=true)
    #@drives.umount(verbose,true)
    #puts "------partition----------"
    #@drives.partition(verbose)
    #puts "------format-------------"
    @drives.format(verbose)
    #@drives.mount(verbose)
    puts "------mkdirs-------------"
    puts "Data dir" + @datadir
    if not file_exists?(@datadir)
      @fileutils.su_mkdir_p @datadir, verbose
    end
    puts "------mount--------------"
    @fileutils.su_mount drive + " " + @datadir
    if not file_exists?(@logdir) 
        if @logdir != ''    	 
            @fileutils.su_mkdir_p @logdir, verbose
        end
    end
    dirall = @datadir+"/*"
    puts "-----Removing datadir----"
    cmd = "sudo rm -rf #{dirall}"
    shell.execute(cmd,verbose=true,status_can_be_nonzero=true)
  end

  def tar_data(verbose)
    @fileutils.su_mkdir_p @config["tar_data"], verbose
    @fileutils.su_du_sh "#{@datadir}", verbose
    @fileutils.su_tar " -C #{@datadir} "," -czf #{File.join(@config["tar_data"],"data.tar.gz")}", ".", verbose
    if @datadir == @logdir
      #log and data dirs are the same so creating empty log.tar.gz
      @fileutils.su_mkdir_p "empty", verbose
      @fileutils.su_tar " -C empty "," -czf #{File.join(@config["tar_data"],"log.tar.gz")}",".", verbose
      @fileutils.su_rm_rf "empty", verbose
    elsif @logdir != ''
      @fileutils.su_tar " -C #{@logdir} "," -czf #{File.join(@config["tar_data"],"log.tar.gz")}",".", verbose
    end
    #shell = SwrShell.new
    #cmd = "cd #{@config["tar_data"]}; du -h; sudo touch md5sums.txt; sudo chmod a+rw md5sums.txt; sudo md5sum data.tar.gz >> md5sums.txt; sudo md5sum log.tar.gz >> md5sums.txt;"
    #shell.execute(cmd,verbose)
    @fileutils.sync verbose
  end

  def teardown(verbose)
    shell = SwrShell.new
    puts "------umount----------"
    #@drives.umount(verbose)
    drive = ENV["SWR_DRIVE"]
    shell.execute("sudo umount #{drive}",true,status_can_be_nonzero=true)
  end

  def start_db(verbose)
    case ENV["SWR_DB_TYPE"]
      when "mysql"
        start_mysql(nil,verbose)
      when "mongodb"
        start_mongodb(verbose)
      when "cassandra"
        start_cassandra(verbose)
    end
  end

  def shutdown_db(verbose)
    case ENV["SWR_DB_TYPE"]
      when "mysql"
        shutdown_mysql(verbose)
      when "mongodb"
        shutdown_mongodb(verbose)
      when "cassandra"
        shutdown_cassandra(verbose)
    end
  end

  def start_mysql(buffer_pool_size,verbose)
    puts "------initializing mysql db------------"
    shell = SwrShell.new
    cmd = "sudo mysql_install_db --datadir=#{@config["mysql"]["named_args"]["datadir"]}"
    shell.execute(cmd,verbose)
    puts "------starting mysqld with buffer_pool_size=#{buffer_pool_size}------------"
    @mysqld = SwrMysqld.new(@config["mysql"])
    if buffer_pool_size != nil
      @mysqld.args["named_args"]["innodb_buffer_pool_size"] = buffer_pool_size
    end
    @mysqld.start(verbose)
    sleep 60
  end

  def start_mongodb(verbose)
    puts "------initializing mongodb------------"
    shell = SwrShell.new
    @mongodb = SwrMongoDB.new(@config["mongodb"])
    @mongodb.start(verbose=true)

  end

  def start_cassandra(verbose)
    puts "------initializing mongodb------------"
    shell = SwrShell.new
    @mongodb = SwrCassandra.new(@config["cassandra"])
    @mongodb.start(verbose=true)

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

  def shutdown_mongodb(verbose)
    @mongodb.shutdown(verbose)
  end

  def shutdown_cassandra(verbose)
    @cassandra.shutdown(verbose)
  end

  def doit(verbose)
    start_db(verbose)
    args_order=["extra_args","short_args","named_args"]
    puts "------starting benchmark------------"
    @benchmark = @benchmarks.get_new(@config["benchmark"],@mysqld)
    @benchmark.make(verbose)
    @benchmark.create(verbose)
    @benchmark.load(verbose)
    shutdown_db(verbose)
    shell = SwrShell.new
  end

  def get_jenkins_parameters
  end

end
