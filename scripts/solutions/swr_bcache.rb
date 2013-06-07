require File.expand_path(File.join(File.dirname(__FILE__),'swr_solution_template.rb'))

class SwrBcache < SwrSolutionTemplate

  def configure(verbose,status_can_be_nonzero=false)
    puts "configuring SwrBcache"
    if @args == nil then return end
    if @args["named_args"] == nil then return end

    @mount_point = @args["named_args"]["mount_point"]
    #puts "mount_point is #{@mount_point}"
    if @mount_point == nil  then return end

    #unmount data since it is already mounted earlier
    cmd = "sudo umount #{@mount_point}"
    @shell.execute(cmd,verbose)

    @source_device = @args["named_args"]["source_device"]
    #puts "source device is #{@source_device}"
    if @source_device == nil then return end

    @cache_device = @args["named_args"]["cache_device"]
    #puts "sdd device is #{@cache_device}"
    if @cache_device == nil then return end

    puts "----------starting bcache----------"
    @shell = SwrShell.new

    cmd = "sudo ./bin/bcache/make-bcache --cache #{@cache_device}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo ./bin/bcache/make-bcache --bdev #{@source_device}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo bash -c \"echo #{@cache_device} > /sys/fs/bcache/register\""
    @shell.execute(cmd, verbose, true)
    
    cmd = "sudo bash -c \"echo #{@source_device} > /sys/fs/bcache/register\""
    @shell.execute(cmd, verbose, true)

    drive = Dir.glob("/dev/bcach*")[0]
    cmd = @args["named_args"]["mkfs_cmd"]+ " #{drive}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo mkdir -p #{@mount_point}"
    @shell.execute(cmd,verbose)
    cmd = "sudo mount -o nobarrier,swalloc #{drive} #{@mount_point}"
    @shell.execute(cmd,verbose)
      
    cmd = "set -u"
    @shell.execute(cmd, verbose)

    cmd = "set -x"
    @shell.execute(cmd, verbose)

    cmd = "set -e"
    @shell.execute(cmd, verbose)
  end
  
  def start(verbose,status_can_be_nonzero=false)

    uuid_dir= Dir['/sys/fs/bcache/*/'][0]
    uuid = uuid_dir.split("/")[-1]
    drive = Dir.glob("/dev/bcach*")[0].split("/")[-1]
    puts "Attaching to set #{drive} set"
    cmd = "sudo bash -c \"echo #{uuid} > /sys/block/#{drive}/bcache/attach\""
    @shell.execute(cmd,verbose)
  end

  def stop(verbose,status_can_be_nonzero=false)
    puts "----------unregistering bcache----------"
    #@mount_point = @args["named_args"]["mount_point"]
    drive = Dir.glob("/dev/bcach*")[0]
    cmd = "sudo umount #{drive}"   
    @shell.execute(cmd,verbose,true)

    uuid_dir= Dir['/sys/fs/bcache/*/'][0]
    cmd = "sudo bash -c \"echo 1 > #{uuid_dir}/unregister\""
    @shell.execute(cmd,verbose)
    drive = Dir.glob("/dev/bcach*")[0]
    if drive != nil
      drive = drive.split("/")[-1]
      puts "removing bcache drive"
      cmd = "sudo bash -c \"echo 1 > /sys/block/#{drive}/bcache/stop\""
      @shell.execute(cmd,verbose)
    end

    
  end
    
end
