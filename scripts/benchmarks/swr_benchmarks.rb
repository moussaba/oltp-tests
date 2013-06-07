require File.expand_path(File.join(File.dirname(__FILE__),'swr_fio.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_sysbench.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_tpcc.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_tpce.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_phoronix.rb'))

class SwrBenchmarks

  def initialize
    @s = Array.new
    @s.push SwrFio.new
    @s.push SwrSysbench.new
    @s.push SwrTpcc.new
    @s.push SwrTpce.new
    @s.push SwrPhoronix.new
  end

  def kill_all(verbose=false,status_can_be_nonzero=true)
    @s.each do |t|
      t.kill_all(verbose,status_can_be_nonzero)
    end
  end

  def stop_all(verbose=false,status_can_be_nonzero=true)
    @s.each do |t|
      t.stop(verbose,status_can_be_nonzero)
    end
  end

  def get_new(args=Hash.new, mysql=nil)
    if args == nil then return SwrBenchmarkTemplate.new(Hash.new,mysql) end
    if args["name"] == "sysbench"
      return SwrSysbench.new(args,mysql)
    elsif args["name"] == "tpcc"
      return SwrTpcc.new(args,mysql)
    elsif args["name"] == "tpce"
      return SwrTpce.new(args,mysql)
    elsif args["name"] == "fio"
      return SwrFio.new(args,mysql)
    elsif args["name"] == "phoronix"
      return SwrPhoronix.new(args)
    end
    return SwrBenchmarkTemplate.new(args,mysql)
  end

end
