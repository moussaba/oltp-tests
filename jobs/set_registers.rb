require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))
require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_cyclone_one_registers.rb'))

class JobSetRegister

attr_accessor :config, :fileutils, :drives

  def initialize(configfile)
    @basedir = Dir.pwd

    @config = set_config
    print_config(@config)
    @fileutils = SwrFileUtils.new
    @drives = SwrDriveHandler.new(@config["drives"])
    @registers = SwrCycloneOneRegisters.new(@config["registers"]["drive_address"],@config["registers"]["drive_num"])
  end

  def iterate_config(h,level,&code)
    level += 1
    if h == nil then return end
    h.each do |k,v|
      code.call(h,k,level)
      if h[k].class == Hash
        if h[k].keys != nil
          iterate_config(h[k],level,&code)
        end
      end
    end
  end

  def print_config(config)
    iterate_config(config,0) do |h,k,l|
      s = ""
      l.times { s += " " }
      if h[k].class == Hash
        s += "[#{k}]"
      else
        s += "[#{k}]='#{h[k]}'"
      end
      puts s
    end
  end

  def set_config
    config = Hash.new
    config["drives"] = Hash.new
    config["registers"] = Hash.new
    config["registers"]["settings"] = Hash.new

    if ENV["DRIVE_TO_SET"] == nil
      raise "Please set environment variable DRIVE_TO_SET"
    end
    if ENV["REGISTER_SETTINGS"] == nil
      raise "Please set environment variable REGISTER_SETTINGS"
    end

    config["drives"]["mounts"] = {ENV["DRIVE_TO_SET"]=>""}

    if ENV["DRIVE_TO_SET"] == "/dev/rssda"
      config["registers"]["drive_address"] = "0000:49:00.0"
      config["registers"]["drive_num"] = 0
    else
      raise "not sure what to do with ENV[\"DRIVE_TO_SET\"] == #{ENV["DRIVE_TO_SET"]}"
    end

    a = ENV["REGISTER_SETTINGS"].split(",")
    a.each do |b|
      c = b.split("-")
      config["registers"]["settings"][c[0]] = c[1]
    end
    return config
  end

  def doit(verbose)
    puts "------umount-------------"
    @drives.umount(verbose,true)
    puts "------restart_firmware-------------"
    @registers.restart_firmware
    puts "------unlock registers-------------"
    @registers.unlock_registers()
    puts "------original state-------------"
    @registers.print_all
    puts "------set registers-------------"
    @registers.set_all(config["registers"]["settings"])
    puts "------new state-------------"
    @registers.print_all
    puts "------lock registers-------------"
    @registers.lock_registers()
  end
end

j = SwrDriveInfo.new

j.print

verbose = true
job = JobSetRegister.new(ARGV)
job.doit(verbose)

j.print
