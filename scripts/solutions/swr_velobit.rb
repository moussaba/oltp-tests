require File.expand_path(File.join(File.dirname(__FILE__),'swr_solution_template.rb'))

class SwrVelobit < SwrSolutionTemplate

  def configure(verbose,status_can_be_nonzero=false)
    if @args == nil then return end
    if @args["named_args"] == nil then return end
    ssd_devices = @args["named_args"]["SSD_devices"]
    reserved_memory = @args["named_args"]["reserved_memory"]
    write_cache_depth = @args["named_args"]["write_cache_depth"]
    sequential_io_filtering = @args["named_args"]["sequential_IO_filtering"]
    mount_point = @args["named_args"]["mount_point"]
    if mount_point == nil then return end
    if ssd_devices == nil then return end
    if reserved_memory == nil then return end
    if write_cache_depth == nil then return end
    if sequential_io_filtering == nil then return end
    target_devices = get_target_device(mount_point)
    if target_devices == nil then return end

    @shell.interactive_execute("sudo veloconfig",verbose,status_can_be_nonzero)
    ["2","q","8"].each do |line|
      @shell.stdin(line,verbose)
    end
    stdout, stderr, status, cmd = @shell.wait_for_interactive_proc(verbose, status_can_be_nonzero)
    target = ""
    stdout.each_line do |line|
      if line.include?(target_devices)
        target = line.split(".")[0].strip
        puts "target[#{target}]"
        break
      end
    end
    sleep(2)
    @shell.interactive_execute("sudo veloconfig",verbose,status_can_be_nonzero)
    ["2","#{target}","y","n","\n"].each do |line|
      @shell.stdin(line,verbose)
    end
    ["3","#{ssd_devices}","y","n","\n"].each do |line|
      @shell.stdin(line,verbose)
    end
    ["4","#{reserved_memory}","\n"].each do |line|
      @shell.stdin(line,verbose)
    end
    ["5","#{write_cache_depth}","\n"].each do |line|
      @shell.stdin(line,verbose)
    end
    ["6","#{sequential_io_filtering}","\n"].each do |line|
      @shell.stdin(line,verbose)
    end
    ["7","y","y"].each do |line|
      @shell.stdin(line,verbose)
    end
    return @shell.wait_for_interactive_proc(verbose, status_can_be_nonzero)
  end

  def start(verbose,status_can_be_nonzero=false)
    cmd  = "sudo velobit start"
    return @shell.execute(cmd,verbose,status_can_be_nonzero)
  end

  def stop(verbose,status_can_be_nonzero=false)
    cmd  = "sudo velobit stop"
    return @shell.execute(cmd,verbose,status_can_be_nonzero)
  end
  
end
