require File.expand_path(File.join(File.dirname(__FILE__),'swr_benchmark_template.rb'))

class SwrFio < SwrBenchmarkTemplate

  def update_args
    @args["kill_all"] = ["fio"]
  end

end