require File.join(File.dirname(__FILE__), 'swr_shell.rb')
require File.join(File.dirname(__FILE__), 'swr_drive.rb')
require File.join(File.dirname(__FILE__), 'swr_drive_info.rb')
require File.join(File.dirname(__FILE__), 'swr_file_utils.rb')

class SwrDriveHandler

  attr_accessor :args

  def initialize(args)
    @args = args
    @drive_info = SwrDriveInfo.new
    @drive = SwrDrive.new
    @fileutils = SwrFileUtils.new
  end

  def is_mounted?(dev)
    if @drive_info.mounts(dev).length == 0
      return false
    end
    return true
  end

  def is_dir_empty?(dir)
    if not File.exists?(dir)
      return true
    end
    so, se = @fileutils.su_ls dir
    count = 0
    if so == nil
      return true
    end
    so.each_line do |line|
      count += 1
    end
    if count == 0
      return true
    end
    return false
  end

  def partition_blockdev(blockdev,parttable,verbose=false)
    if is_mounted?(blockdev)
      raise "refusing to partition #{blockdev}, it is mounted {#{@drive_info.str_format_dev(blockdev)}}"
    end
    parts = Array.new
    ids = Array.new
    starts = Array.new
    parttable.each do |part,h|
      parts.push h["size"]
      ids.push h["id"]
    end
    return @drive.partition(blockdev, parts, verbose, ids)
  end

  def umount_drive(dev,verbose=false)
    retvals = Array.new
    @drive_info.mounts(dev).each do |part|
      retvals.push @drive.umount(part,verbose,true)
    end
    return retvals
  end

  def format_partition(part,params,verbose=false)
    if is_mounted?(part)
      raise "refusing to format #{part}, it is mounted {#{@drive_info.str_format_dev(part.gsub(/\d+/,""))}}"
    end
    fstype = params["type"]
    if params["extra_args"] != nil
      extra_args = params["extra_args"]
    else
      extra_args = ""
    end
    if params["label"] != nil
      label = params["label"]
    else
      label = "test_drive"
    end
    return @drive.format(part,fstype,extra_args,verbose,label)
  end

  def partition(verbose=false)
    retvals = Array.new
    if @args["partitions"] == nil then return retvals end
    @args["partitions"].each do |blockdev,parttable|
      retvals.push partition_blockdev(blockdev,parttable,verbose)
    end
    return retvals
  end

  def do_format(verbose=false)
    retvals = Array.new
    if @args["partitions"] == nil then return retvals end
    @args["partitions"].each do |blockdev,parttable|
      parttable.each do |part,h|
        if h["format"] != nil
          retvals.push format_partition(part,h["format"],verbose)
        end
      end
    end
    return retvals
  end

  def do_mount(verbose=false)
    retvals = Array.new
    if @args["mounts"] == nil then return retvals end
    @args["mounts"].each do |part,params|
      if is_mounted?(part)
        raise "refusing to mount #{part}, it is already mounted {#{@drive_info.str_format_dev(part.gsub(/\d+/,""))}}"
      end
      if not is_dir_empty?(params["path"])
        raise "refusing to mount to non empty target directory #{params["path"]}"
      end
      if not File.exists?(params["path"])
        retvals.push @fileutils.su_mkdir_p params["path"], verbose
      end
      if params["extra_args"] != nil
        extra_args = params["extra_args"]
      else
        extra_args = ""
      end
      retvals.push @drive.mount(part,params["path"],extra_args,verbose)
    end
    return retvals
  end

  def link(verbose=false)
    retvals = Array.new
    if @args["links"] == nil then return retvals end
    @args["links"].each do |target,params|
      if not is_dir_empty?(target)
        raise "refusing to link non empty target directory #{target}"
      end
      if File.exists?(params["symbolic_link"])
        raise "refusing to link to existing symblic link file #{params["symbolic_link"]}"
      end
      if not File.exists?(File.dirname(params["symbolic_link"]))
        retvals.push @fileutils.su_mkdir_p File.dirname(params["symbolic_link"])
      end
      retvals.push @fileutils.su_ln_s target, params["symbolic_link"], verbose
    end
    return retvals
  end

  def mount(verbose=false)
    retvals = Array.new
    retvals += do_mount(verbose)
    retvals += link(verbose)
    return retvals
  end

  def umount(verbose=false,status_can_be_nonzero=false)
    retvals = Array.new
    if @args["mounts"] != nil
      @args["mounts"].each do |part,params|
        retvals.push @drive.umount(part,verbose,status_can_be_nonzero)
      end
    end
    if @args["links"] != nil
      @args["links"].each do |target,params|
        if File.exists?(params["symbolic_link"])
          retvals.push @fileutils.su_rm params["symbolic_link"], verbose
        end
      end
    end
  end

  def format(verbose=false)
    retvals = do_format(verbose)
    if @args["links"] != nil
      @args["links"].each do |target,params|
        retvals.push @fileutils.su_rm_rf target, verbose
        retvals.push @fileutils.su_mkdir_p target, verbose
      end
    end
    return retvals
  end

  def copy_data(verbose=false)
    retvals = Array.new
    if @args["source_data"] == nil then return retvals end
    @args["source_data"].each_value do |h|
      if h["src"].split(".")[-1] == "gz"
        retvals.push @fileutils.su_tar " -C #{h["dst"]} ", " -xzf #{h["src"]}", ".", verbose
      elsif h["src"].split(".")[-1] == "bz2"
        retvals.push @fileutils.su_tar " -C #{h["dst"]} ", " -xjf #{h["src"]}", ".", verbose
      else
        retvals.push @fileutils.su_tar " -C #{h["dst"]} ", " -xf #{h["src"]}", ".", verbose
      end
    end
    return retvals
  end

end