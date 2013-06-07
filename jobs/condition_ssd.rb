require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_fio.rb'))

class JobConditionSsd < SwrJob

  def setup(dev,verbose)
    puts "------umount----------"
    @drives.umount_drive(dev,verbose)
  end

  def doit(dev,verbose)
    di = SwrDriveInfo.new
    size = di.size(dev,"B")
    puts "------starting fio------------"
    fio = SwrFio.new(Hash.new)
    @config.each do |k,v|
      puts "------fio run '#{k}'------------"
      v["named_args"]["filename"] = dev
      v["named_args"]["size"] = size
      fio.args = v
      fio.start(verbose)
    end
  end

end

dev = ENV["SSD_TO_CONDITION"]

if dev == nil
  raise "please set environment variable 'SSD_TO_CONDITION'"
end

if dev.length < "/dev/a".length
  raise "I have a hard time believing that you have a proper devnod '#{dev}' with a name shorter than /dev/a"
end

if not File.exists?(dev)
  raise "'#{dev}' doesn't seem to exist"
end

if not File.stat(dev).blockdev?
  raise "'#{dev}' doesn't seem to be a block device"
end

verbose = true
job = JobConditionSsd.new(ARGV[0])
job.setup(dev,verbose)
job.doit(dev,verbose)
