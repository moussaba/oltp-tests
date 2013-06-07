require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','benchmarks','swr_fio.rb'))

class JobFioSweeps < SwrJob

  def setup(dev,verbose)
    puts "------kill all----------"
    kill_all(verbose,true)
    puts "------umount----------"
    @drives.umount_drive(dev,verbose)
  end

  def run_jobs(verbose)
    puts "run_jobs"
    retvals = Array.new
    @config["jobs"].each_key do |job_name|
      retvals += sweep_job(job_name,@config["sweeps"][job_name],verbose)
    end
    return retvals
  end

  def sweep_globals(gsweeps,verbose)
    if gsweeps == nil
      puts "sweep_globals(nil)"
      return run_jobs(verbose)
    elsif gsweeps.length == 0
    puts "sweep_globals(0)"
      return run_jobs(verbose)
    end
    puts "sweep_globals(#{gsweeps.length})"
    retvals = Array.new
    sweep_name = gsweeps.keys.sort.pop
    puts "\tsweep_name=#{sweep_name}"
    sweep = gsweeps[sweep_name]
    if sweep == nil
      puts "global sweep_name=#{sweep_name} == nil"
      return retvals
    end
    sweep.each do |value|
      @fio.args["global"][sweep_name] = value
      gs_two = gsweeps.clone
      gs_two.delete(sweep_name)
      retvals += sweep_globals(gs_two,verbose)
    end
    return retvals
  end

  def sweep_job(job_name,jsweeps,verbose)
    if jsweeps == nil
      #puts "sweep_job(nil)"
      make_command_file(job_name)
      puts "------ running fio job -------"
      return @fio.start(verbose)
    elsif jsweeps.length == 0
      #puts "sweep_job(0)"
      make_command_file(job_name)
      return @fio.start(verbose)
    end
    #puts "sweep_job(#{jsweeps.length})"
    retvals = Array.new
    sweep_name = jsweeps.keys.pop
    #puts "\tsweep_name=#{sweep_name}"
    sweep = jsweeps[sweep_name]
    jsweeps.delete(sweep_name)
    if sweep == nil
      puts "job sweep_name=#{sweep_name} == nil"
      return retvals
    end
    sweep.each do |value|
      @fio.args["jobs"][job_name][sweep_name] = value
      retvals += sweep_job(job_name,jsweeps,verbose)
    end
    return retvals
  end

  def doit(dev,verbose)
    puts "------starting fio------------"
    @fio = SwrFio.new(@config)
    @fio.args["extra_args"] = "fio_command_file.txt" 
    @config["global"]["filename"] = dev
    sweep_globals(@config["sweeps"]["global"],verbose)
    @fileutils.su_rm "fio_command_file.txt"
  end
  
  def make_command_file(run_name)
    #puts "make_command_file(#{run_name}) {"
    f = File.new("fio_command_file.txt", "w+")
    f.puts "[global]"
    @config["global"].each do |key, value|
      if value == nil
        f.puts "#{key}"
      else
        f.puts "#{key}=#{value}"
      end
    end
    f.puts "[#{run_name}]"
    @config["jobs"][run_name].each do |key, value|
      if value == nil
        #puts "#{key}"
        f.puts "#{key}"
      else
        #puts "#{key}=#{value}"
        f.puts "#{key}=#{value}"
      end
    end
  #f.seek(0)
  #puts f.read
  #puts "}"
  f.close
  puts File.read("fio_command_file.txt")
  end
end

dev = ENV["DRIVE_TO_BASELINE"]

if dev == nil
  puts "dev is #{dev}"
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
#puts ENV['SWR_CONFIGFILE_FIO']
job = JobFioSweeps.new(ENV['SWR_CONFIGFILE_FIO'])
job.setup(dev,verbose)
job.doit(dev,verbose)
