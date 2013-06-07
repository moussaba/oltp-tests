require File.expand_path(File.join(File.dirname(__FILE__),'create_data_template.rb'))

class JobSysbenchCreateData < JobCreateDataTemplate

  def get_jenkins_parameters
    rows = ENV["MILLIONS_OF_ROWS"]
    tables = ENV["NUMBER_OF_TABLES"]
    @config["benchmark"]["named_args"]["oltp-table-size"] = 1000000 * rows.to_i
    @config["benchmark"]["named_args"]["oltp_tables_count"] = tables.to_i
    @config["tar_data"] += rows.to_s + "M"+"_ROWS_" + tables.to_s+"_TABLES"

  end

end

verbose = true
job = JobSysbenchCreateData.new(ARGV)
job.get_jenkins_parameters
t = Time.now
job.setup(verbose)
job.doit(verbose)
job.tar_data(verbose)
job.teardown(verbose)
