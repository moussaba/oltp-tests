require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_mysql_benchmarks.rb'))

# Must have @config['env'] optiosn for both tpcc and sysbench
#
#--for sysbench--
# SWR_MILLIONS_OF_ROWS=10
# SWR_NUMBER_OF_TABLES=100
#
#--for tpcc--
# SWR_WAREHOUSES=2500

class JobCreateMySqlData < SwrJob

  def initialize(args)
    super(args)
    @required_env_vars = ["SWR_DRIVE"]
    @optional_env_vars = ["SWR_MILLIONS_OF_ROWS","SWR_NUMBER_OF_TABLES","SWR_WAREHOUSES"]
    @required_config_sections = ["benchmark","mysql","tar_data"]
    validate_config()
    @datadir = @config["mysql"]["named_args"]["datadir"]
    @logdir = @config["mysql"]["named_args"]["innodb_log_group_home_dir"]
    @drive = @config['env']["SWR_DRIVE"]
    @benchmarks = SwrMySqlBenchmarks.new
    @benchmarks.set_parameters(@config)
  end

  def setup(verbose)
    shell = SwrShell.new
    puts "------umount----------"
    @fileutils.sync verbose
    shell.execute("sudo umount #{@drive}",true,status_can_be_nonzero=true)
    puts "-----Making File System---------"
    shell.execute("sudo mkfs.ext4 -F #{@drive}",true)
    puts "------mkdirs-------------"
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
    puts "-----cleaning datadir----"
    dirall = @datadir+"/*"
    @fileutils.su_rm_rf dirall, verbose
  end

  def tar_data(verbose)
    @fileutils.su_mkdir_p @config["tar_data"], verbose
    @fileutils.su_du_sh "#{@datadir}", verbose
    @fileutils.su_tar " -C #{@datadir} "," -cf #{File.join(@config["tar_data"],"data.tar")}", ".", verbose
    if @datadir == @logdir
      #log and data dirs are the same so creating empty log.tar.gz
      @fileutils.su_mkdir_p "empty", verbose
      @fileutils.su_tar " -C empty "," -cf #{File.join(@config["tar_data"],"log.tar")}",".", verbose
      @fileutils.su_rm_rf "empty", verbose
    elsif @logdir != ''
      @fileutils.su_tar " -C #{@logdir} "," -cf #{File.join(@config["tar_data"],"log.tar")}",".", verbose
    end
    shell = SwrShell.new
    cmd = "cd #{@config["tar_data"]}; du -h; sudo touch md5sums.txt; sudo chmod a+rw md5sums.txt; sudo md5sum data.tar.gz >> md5sums.txt; sudo md5sum log.tar.gz >> md5sums.txt;"
    shell.execute(cmd,verbose)
    @fileutils.sync verbose
  end

  def teardown(verbose)
    shell = SwrShell.new
    puts "------umount----------"
    shell.execute("sudo umount #{@drive}",true,status_can_be_nonzero=true)
  end

  def start_db(verbose)
    puts "------initializing mysql db------------"
    shell = SwrShell.new
    cmd = "sudo mysql_install_db --datadir=#{@datadir}"
    shell.execute(cmd,verbose)
    @db = SwrMysqld.new(@config["mysql"])
    puts "------starting mysqld -----------------"
    @db.start(verbose)
    sleep 60
  end

  def shutdown_db(verbose)
    @db.shutdown(verbose)
    puts "-mysql had this to say ----------------"
    stdout, stderr, status, cmd = @db.wait
    puts "cmd[#{cmd}]"
    puts "stdout[#{stdout.chomp}]"
    puts "stderr[#{stderr.chomp}]"
    puts "status[" + status.to_s + "]"

  def doit(verbose)
    start_db(verbose)
    puts "------starting benchmark------------"
    @benchmark = @benchmarks.get_new(@config["benchmark"],@db)
    @benchmark.make(verbose)
    @benchmark.create(verbose)
    @benchmark.load(verbose)
    shutdown_db(verbose)
  end

end

verbose = true
job = JobCreateMySqlData.new(ARGV)
job.setup(verbose)
job.doit(verbose)
job.tar_data(verbose)
job.teardown(verbose)