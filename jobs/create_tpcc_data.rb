require File.expand_path(File.join(File.dirname(__FILE__),'create_data_template.rb'))

class JobTpccCreateData < JobCreateDataTemplate

  def get_jenkins_parameters
    warehouses = ENV["WAREHOUSES"]
    @config["benchmark"]["unamed_args"][4] = warehouses.to_i
    @config["benchmark"]["warehouses"] = warehouses.to_i
    @config["tar_data"] += warehouses.to_s
    @config["mysql"]["dbname"] += warehouses.to_s
  end

end

verbose = true
job = JobTpccCreateData.new(ARGV)
job.get_jenkins_parameters
t = Time.now
job.setup(verbose)
job.doit(verbose)
job.tar_data(verbose)
job.teardown(verbose)
