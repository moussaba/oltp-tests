require File.join(File.dirname(__FILE__),'swr_common.rb')
require File.join(File.dirname(__FILE__),'..','benchmarks','swr_benchmarks.rb')
require File.join(File.dirname(__FILE__),'..','solutions','swr_solutions.rb')

require 'yaml'

class SwrJob

  attr_accessor :config, :fileutils, :drives

  def initialize(configfile)
    @basedir = Dir.pwd
    config = process_configfiles(configfile)
    @config = scrub_paths(config)
    print_config(@config)
    @fileutils = SwrFileUtils.new
    @drives = SwrDriveHandler.new(@config["drives"])
    @solutions = SwrSolutions.new
    @benchmarks = SwrBenchmarks.new
  end

  def process_configfiles(configfile)
    if configfile.class == String
      if not File.exists?(configfile)
        raise "Configuration YAML file '#{configfile}' doesn't exist"
      end
      return YAML::load(File.open(configfile))
    elsif configfile.class == Hash
      return configfile
    elsif configfile.class == Array
      if configfile.length == 0
        return get_config_from_env
      else
        return merge_configfiles(configfile)
      end
    end
    return  Hash.new
  end

  def get_config_from_env
    configfiles = Array.new
    ENV.each do |key, value|
      if key =~ /SWR_CONFIGFILE_/
        configfiles.push File.expand_path(File.join("config",value))
      end
    end
    return merge_configfiles(configfiles.sort)
  end

  def merge_configfiles(configfiles)
    config = Hash.new
    configfiles.each do |file|
      if not File.exists?(file)
        raise "Configuration YAML file '#{file}' doesn't exist"
      end
      puts file
      src = YAML::load(File.open(file))
      do_merge(config,src)
    end
    return config
  end

  def do_merge(dst,src)
    if src == nil then return end
    src.each do |k,v|
      if dst[k].class == Hash
        if v.class != Hash
          raise "what?  I can't merge a '#{v.class.to_s}' object into a 'Hash' object"
        end
        do_merge(dst[k],v)
      else
        dst[k] = v
      end
    end
  end

  def scrub_paths(config)
    iterate_config(config,0) do |h,k,l|
      if h[k].class == String and h[k] =~ /^\.\//
        path = File.join(@basedir,h[k])
        h[k] = File.expand_path(path)
      end
    end
    return config
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

  def kill_all(verbose=false,status_can_be_nonzero=true)
    stop_all(verbose)
    @solutions.kill_all(verbose,status_can_be_nonzero)
    @benchmarks.kill_all(verbose,status_can_be_nonzero)
    mysqld = SwrMysqld.new("")
    mysqld.kill_all(verbose,status_can_be_nonzero)
  end

  def stop_all(verbose=false,status_can_be_nonzero=true)
    @solutions.stop_all(verbose,status_can_be_nonzero)
    @benchmarks.stop_all(verbose,status_can_be_nonzero)
  end

  def file_exists?(file)
    if File.exists?(file) or File.symlink?(file)
      return true
    end
    return false
  end

end

