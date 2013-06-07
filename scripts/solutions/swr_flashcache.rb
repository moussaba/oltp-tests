require File.expand_path(File.join(File.dirname(__FILE__),'swr_solution_template.rb'))

class SwrFlashcache < SwrSolutionTemplate

  def configure(verbose,status_can_be_nonzero=false)
    if @args == nil then return end
    if @args["named_args"] == nil then return end

    @ssd_devices = @args["named_args"]["SSD_devices"]
    if @ssd_devices == nil then return end
      
    @cache_mode = @args["named_args"]["cache_mode"]
    if @cache_mode == nil  then return end
      
    @cache_size = @args["named_args"]["cache_size"]

    @mount_point = @args["named_args"]["mount_point"]
    if @mount_point == nil  then return end

    @flashcache_mod = @args["named_args"]["flashcache_mod"]
    if @flashcache_mod == nil  then return end

    @target_devices = get_target_device(@mount_point)
    if @target_devices == nil then return end

  end

  def start(verbose,status_can_be_nonzero=false)
    cmd = "sudo /sbin/insmod bin/flashcache/#{@flashcache_mod}" 
    @shell.execute(cmd,verbose,true)
    
    cmd = "sudo umount #{@mount_point}"   
    @shell.execute(cmd,verbose,true)
    
    cmd = "sudo bin/flashcache/flashcache_destroy -f #{@ssd_devices}"
    @shell.execute(cmd,verbose,true)

    cmd = "sudo su -"
    @shell.interactive_execute(cmd,verbose)
    if @cache_size == nil  then
      cmd = "sudo #{Dir.pwd}/bin/flashcache/flashcache_create -p #{@cache_mode} -b 4k cachedev #{@ssd_devices} #{@target_devices}"
    else
      cmd = "sudo #{Dir.pwd}/bin/flashcache/flashcache_create -p #{@cache_mode} -s #{@cache_size} -b 4k cachedev #{@ssd_devices} #{@target_devices}"
    end
    @shell.stdin(cmd,verbose)
    @shell.wait_for_interactive_proc(verbose,true)
    
    cmd = "sudo mount -o nobarrier,swalloc /dev/mapper/cachedev #{@mount_point}"
    @shell.execute(cmd,verbose)
  end

  def stop(verbose,status_can_be_nonzero=false)
    cmd = "sudo umount #{@mount_point}"
    @shell.execute(cmd,verbose,true)

    cmd = "sudo /sbin/dmsetup status cachedev"
    @shell.execute(cmd,verbose,true)

    cmd = "sudo /sbin/dmsetup remove cachedev"
    @shell.execute(cmd,verbose,true)

    cmd = "sudo bin/flashcache/flashcache_destroy -f #{@ssd_devices}"
    @shell.execute(cmd,verbose,true)

    cmd = "sudo /sbin/rmmod flashcache"
    @shell.execute(cmd,verbose,true)

  end

end
