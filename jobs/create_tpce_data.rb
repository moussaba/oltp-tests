require File.expand_path(File.join(File.dirname(__FILE__),'create_data_template.rb'))

class JobTpceCreateData < JobCreateDataTemplate

  def setup(verbose)
    super
    if not file_exists?(@config["benchmark"]["short_args"]["o"])
      @fileutils.su_mkdir_p @config["benchmark"]["short_args"]["o"], verbose
    end
    flatout_src = File.join(@config["mysql"]["named_args"]["datadir"],"flat_out")
    if not file_exists?(flatout_src)
      @fileutils.su_rm_rf flatout_src, verbose
      @fileutils.su_mkdir_p flatout_src, verbose
    end
  end

  def clean_flatout(verbose)
    puts "-----------Cleaning out flat out -----"
    shell = SwrShell.new
    cmd = "sudo rm -rf ./bin/tpce-mysql/flat_out/*"
    shell.execute(cmd,verbose)
  end

  def get_jenkins_parameters
    customers = ENV["CUSTOMERS"]
    @config["benchmark"]["short_args"]["c"] = customers.to_i
    @config["benchmark"]["short_args"]["t"] = customers.to_i
    @config["tar_data"] += customers.to_s
    @config["mysql"]["dbname"] += customers.to_s
  end

end

verbose = true
job = JobTpceCreateData.new(ARGV)
job.get_jenkins_parameters
t = Time.now
job.setup(verbose)
job.doit(verbose)
job.clean_flatout(verbose)
job.tar_data(verbose)
job.teardown(verbose)
