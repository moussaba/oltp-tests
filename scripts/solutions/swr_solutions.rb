require File.expand_path(File.join(File.dirname(__FILE__),'swr_velobit.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_vfcache.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_flashcache.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'swr_bcache.rb'))

class SwrSolutions

  def initialize
    @s = Array.new
    @s.push SwrVelobit.new
    #@s.push SwrVfcache.new
    #@s.push SwrFlashcache.new
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

  def get_new(args=Hash.new,config=Hash.new)
    if args == nil then return SwrSolutionTemplate.new end
    case args["name"]
    when "velobit"
      return SwrVelobit.new(args,config)
    when "vfcache"
      return SwrVfcache.new(args,config)
    when "flashcache"
      return SwrFlashcache.new(args,config)
    when "bcache"
      return SwrBcache.new(args,config)
    else
      return SwrSolutionTemplate.new(args,config)
    end
  end

end
