require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_sysbench.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_shell.rb'))


class JobRunPhoronix < SwrJob

  def setup(verbose)
    puts "------kill off stuff-----"
    kill_all(verbose,true)
    puts "------umount-------------"
    @fileutils.sync verbose
    @drives.umount(verbose,true)
    puts "------clean up-----------"
    @fileutils.su_rm_rf @config["drives"]["source_data"]["data"]["dst"], verbose
    puts "------partition----------"
    @drives.partition(verbose)
    puts "------format-------------"
    @drives.format(verbose)
    puts "------mount--------------"
    @drives.mount(verbose)
    puts "------mkdirs-------------"
    if not file_exists?(@config["drives"]["source_data"]["data"]["dst"])
      @fileutils.su_mkdir_p @config["drives"]["source_data"]["data"]["dst"]
    end
    puts "------cp data-------------"
    @drives.copy_data(verbose)
    dirname = @config["drives"]["source_data"]["data"]["dst"]
    shell = SwrShell.new
    cmd = "sudo chown -R jenkins.jenkins #{dirname}"
    shell.execute(cmd,true)
    @benchmark = @benchmarks.get_new(@config["benchmark"])
    @benchmark.load(verbose)
  end  

  def teardown(verbose)
    #Remove Installed tests
  end

  def doit(verbose)
    @config["trials"].times do |i|
        puts "------running benchmark trial #{(i+1).to_s}------------"
        @benchmark.start(verbose)
      end
  end

end

j = SwrDriveInfo.new
j.print
verbose = true
job = JobRunPhoronix.new(ARGV)
job.setup(verbose)
job.doit(verbose)
#job.teardown(verbose)

j.print
