require File.join(File.dirname(__FILE__),'swr_common.rb')

require 'yaml'

class SwrJob

  attr_accessor :config, :fileutils

  def initialize(args)
    @basedir = Dir.pwd
    config = process_configfiles(args)
    @config = scrub_paths(config)
    #print_config(@config)
    @fileutils = SwrFileUtils.new
  end

  #A job has a @config hash full of setting useful for the various layers
  # that make up the job, mysql and sysbench for example.  We construct that
  # hash by parsing YAML files and merging the resulting hashs mostly.
  def process_configfiles(args)
    #if the caller passes a Hash then we're going to assume it's a proper
    # config hash and that we've got nothing intelligent to add.
    if args.class == Hash
      return args
    end

    #if we've been passed an array then we're likely looking at a command line
    # option array to parse through
    if args.class == Array
      #Let's strip out any SWR_*= args because they are not configfiles by
      # convention.  We'll deal with them after we merge the configfiles.
      configfiles = Array.new
      args.each do |arg|
        if not arg =~ /^SWR_[A-Z_]*=/
          configfiles.push arg
        end
      end

      #extract any configfiles from the environment variables.
      # Convention: any env var starting with SWR_CONFIGFILE_ is a config file
      # env var files are merged after commandline files
      configfiles_from_env = get_configfiles_from_env()

      configfiles_from_env.each do |file|
        configfiles.push file
      end

      #We'll read in the YAML files and merge the hashes into one master hash
      config = merge_configfiles(configfiles)

      #Now we can handle the special args that aren't configfiles.  First we'll
      # handle the commandline arguments then we'll merge the env vars on top.
      config['env'] = Hash.new
      args.each do |arg|
        if arg =~ /^(SWR_[A-Z_]*)=(.*)/
          config['env'][$1]=strip_parens($2)
        end
      end
      ENV.keys.sort.each do |key|
        if key =~ /^SWR_[A-Z_]*/ and not key =~ /^SWR_CONFIGFILE_/
          config['env'][key]=ENV[key]
        end
      end
      return config
    end

    #I dunno what to do here so I just return empty...
    return  Hash.new
  end

  def get_configfiles_from_env
    configfiles = Array.new
    ENV.keys.sort.each do |key|
      if key =~ /^SWR_CONFIGFILE_/
        configfiles.push File.expand_path(File.join("config",ENV[key]))
      end
    end
    return configfiles
  end

  def merge_configfiles(configfiles)
    config = Hash.new
    configfiles.each do |file|
      if not File.exists?(file)
        raise "Configuration YAML file '#{file}' doesn't exist"
      end
      #puts file
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

  def strip_parens(str)
    if str =~ /"$/
      str.chop!
    end
    if str =~ /^"(.*)/
      str = $1
    end
    return str
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

  def file_exists?(file)
    if File.exists?(file) or File.symlink?(file)
      return true
    end
    return false
  end

end

