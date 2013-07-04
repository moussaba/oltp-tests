require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_fio.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_shell.rb'))

class JobBaselineFio < SwrJob
  @run_name = ""

  def setup(dev,verbose)
    puts "------umount----------"
    puts dev
    #@drives.umount_drive(dev,verbose) - for some reason this results in wrong path - troubleshoot later
    puts "path to unmount is #{dev}"
    cmd = "sudo umount #{dev}"
    shell = SwrShell.new
    return shell.execute(cmd,verbose,status_can_be_nonzero=true)

  end

  def part_drive(dev)
    dr = SwrDrive.new #is @drive the right var for this? debug later
    parts = Array.new
    parts[0] = @config["partition"]["size"]
    dr.partition(dev, parts, verbose=true)
  end

  def format_drive(dev,file_system_type)
    dr = SwrDrive.new #@drive doesn't work for this - debug later
    extra_args = @config["partition"]["format"]["extra_args"]
    label = @config["partition"]["format"]["label"]
    dr.format(dev, file_system_type, extra_args , verbose=true, label )
  end

  def doit(dev,verbose)
    puts "------starting fio------------"
    fio = SwrFio.new(@config)
    fio.args["extra_args"] = "fio_command_file.txt"
    common_params = @config["global"]
    common_params["filename"] = dev
    @config["jobs"].each do |run_name,j,k,l,m|
      puts "------fio run '#{run_name}'------------"
      make_command_file(common_params, run_name)
      fio.start(verbose)
    end
  end

  def make_command_file(common_params, run_name)
    f = File.new("fio_command_file.txt", "w")
    f.puts "[global]"
    common_params.each do |key, value|
      if value == nil
        f.puts "#{key}"
      else
        f.puts "#{key}=#{value}"
      end
    end

    #this section creates a job name based on job specific parameters instead of run_name
    #this keeps runs from overwriting each other's log files
    #it constructs the name in the order the parameters are entered in the yaml config script
    @config["jobs"][run_name].each_with_index do |(key, value), i|
      if i == 0
        @run_name = "#{value}"
      else
        @run_name = @run_name + "#{value}"
      end
      @run_name = @run_name + "_" if i + 1 < @config["jobs"][run_name].length
    end
    #probably want to add device name to end of filename example "_rssda"
    f.puts "[#{@run_name}]"

    @config["jobs"][run_name].each do |key, value|
      if value == nil
        f.puts "#{key}"
      else
        f.puts "#{key}=#{value}"
      end
    end
    f.close
    puts `cat fio_command_file.txt`
  end
end

dev = ENV["DRIVE_TO_BASELINE"]
dev1 = dev + "1"

create_partition = ENV["CREATE_PARTITION"]
file_system_type = ENV["FILE_SYSTEM"]

if dev == nil
  raise "please set environment variable 'DRIVE_TO_BASELINE'"
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
job = JobBaselineFio.new(ARGV[0])
if create_partition == "true"
  puts "device is #{dev1}"
  job.setup(dev1,verbose)
  job.part_drive(dev)
  job.format_drive(dev1, file_system_type)
  dev = dev1
end
puts "running job on #{dev}"
job.doit(dev,verbose)
