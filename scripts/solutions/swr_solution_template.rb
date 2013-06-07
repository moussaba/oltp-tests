require File.expand_path(File.join(File.dirname(__FILE__),'..','common','swr_common.rb'))

class SwrSolutionTemplate

  attr_accessor :args

  def initialize(args=Hash.new,parent_config=Hash.new)
    @parent_config = parent_config
    @args = args
    update_args
    @shell = get_shell
  end

  def update_args
  end

  def get_target_device(mount_point)
    dev = ""
    @parent_config["drives"]["mounts"].each do |dev,h|
      if h["path"] == mount_point
        return dev
      end
    end
    return nil
  end

  def get_shell
    if @args["ssh"] == nil
      return SwrShell.new
    end
    ssh = @args["ssh"]
    return SwrSsh.new(ssh["host"], ssh["username"], ssh["password"], ssh["timeout"])
  end

  def kill_all(verbose=false,status_can_be_nonzero=true)
    if @args["kill_all"] == nil
      return
    end
    if @args["kill_all"].class == String
      procs = Array.new
      procs.push @args["kill_all"]
    elsif @args["kill_all"].class == Array
      procs = @args["kill_all"]
    else
      return
    end
    procs.each do |k|
      so, se = @shell.execute_no_override("ps aux | grep #{k} | grep -v ruby")
      if verbose then puts so end
      so.each_line do |l|
        pid = l.split[1]
        cmd = "sudo kill -9 #{pid}"
        @shell.execute(cmd,verbose,status_can_be_nonzero)
      end
    end
  end

  def start(verbose,status_can_be_nonzero=false)
  end

  def stop(verbose=false,status_can_be_nonzero=false)
  end

  def configure(verbose,status_can_be_nonzero=false)
  end

end