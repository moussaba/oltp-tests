require File.expand_path(File.join(File.dirname(__FILE__),'..','common','swr_shell.rb'))

class SwrBenchmarkTemplate

  attr_accessor :args

# args["binary"] = path for the actual binary
# args["named_args"]   = a hash with named arguments that can be easily parsed via --key=value
# args["extra_args"] = freeform text appended to the end, arguments that don't fit the model
# mysql = an SwrMysqld object
  def initialize(args=Hash.new, mysql=nil)
    @args = args
    @mysql = mysql
    if @mysql == nil
      @socket_arg = ""
    elsif @mysql.socket == nil
      @socket_arg = ""
    else
      @socket_arg = " --socket=#{@mysql.socket} "
    end
    update_args
    @shell = get_shell
  end

  def get_shell
    if @args["ssh"] == nil
      return SwrShell.new
    end
    ssh = @args["ssh"]
    return SwrSsh.new(ssh["host"], ssh["username"], ssh["password"], ssh["timeout"])
  end

  def update_args
  end

  def process_named_args(named_args)
    s = ""
    if named_args == nil
      return s
    end
    named_args.each do |k,v|
      s += " --#{k}=#{v.to_s}"
    end
    return s
  end

  def process_short_args(short_args)
    s = ""
    if short_args == nil
      return s
    end
    short_args.each do |k,v|
      s += " -#{k} #{v.to_s}"
    end
    return s
  end

  def process_unnamed_args(unnamed_args)
    s = ""
    if unnamed_args == nil
      return s
    end
    unnamed_args.each do |v|
      s += " #{v.to_s}"
    end
    return s
  end

  def timeout_run(cmd, verbose=false,timeout=600)
    retvals = Array.new
    shell = SwrShell.new
    Timeout.timeout(timeout) do
      while true do
        sleep 1
        stdout, stderr, status, cmd = shell.execute(cmd,verbose,true)
        retvals.push stdout, stderr, status, cmd
        if status == 0
          break
        end
      end
    end
    return retvals
  end

  def start(verbose=false)
    if @args["binary"] == nil then return Array.new end
    cmd = "sudo #{@args["binary"]} "
    cmd += process_named_args(@args["named_args"])
    cmd += process_short_args(@args["short_args"])
    cmd += process_unnamed_args(@args["unnamed_args"])
    cmd += " #{@args["extra_args"]} "
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
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
      so, se = @shell.execute_no_override("ps aux | grep #{k} | grep -v ruby",true,true)
      if verbose then puts so end
      so.each_line do |l|
        pid = l.split[1]
        cmd = "sudo kill -9 #{pid}"
        @shell.execute(cmd,verbose,status_can_be_nonzero)
      end
    end
  end

  def warmup(verbose=false)
  end

  def start_stats(verbose=false)
    if @args["stats_binary"] == nil then return end
    cmd = "#{@args["stats_binary"]["name"]} "
    cmd += process_named_args(@args["stats_binary"]["named_args"])
    cmd += process_short_args(@args["stats_binary"]["short_args"])
    cmd += process_unnamed_args(@args["stats_binary"]["unnamed_args"])
    cmd += " #{@args["stats_binary"]["extra_args"]} "
    puts "----Sending Stats Command ------"
    puts cmd
    shell = SwrShell.new
    return shell.background_execute(cmd,verbose)
  end

  def set_benchmark_warmup_time
  end

  def set_benchmark_run_time
  end

  def stop(verbose=false,status_can_be_nonzero=true)
  end

  def load(verbose=false)
    return start(verbose)
  end

  def make(verbose=false)
  end

  def set_parameters(config)
  end

end
