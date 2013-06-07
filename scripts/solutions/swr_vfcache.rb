require File.expand_path(File.join(File.dirname(__FILE__),'swr_solution_template.rb'))

class SwrVfcache < SwrSolutionTemplate

  def configure(verbose,status_can_be_nonzero=false)
    puts "configuring SwrVfcache"
    if @args == nil then return end
    if @args["named_args"] == nil then return end

    @mount_point = @args["named_args"]["mount_point"]
    #puts "mount_point is #{@mount_point}"
    if @mount_point == nil  then return end

    @source_device = @args["named_args"]["source_device"]
    #puts "source device is #{@source_device}"
    if @source_device == nil then return end

    @ssd_device = @args["named_args"]["SSD_device"]
    #puts "sdd device is #{@sdd_device}"
    if @ssd_device == nil then return end
      
    cmd = "set -u"
    @shell.execute(cmd, verbose)

    cmd = "set -x"
    @shell.execute(cmd, verbose)

    cmd = "set -e"
    @shell.execute(cmd, verbose)
  end
  
  def start(verbose,status_can_be_nonzero=false)
    puts "----------starting vfcache----------"
    @shell = SwrShell.new

    cmd = "sudo /etc/init.d/SFC start"
    @shell.execute(cmd, verbose)

    cmd = "sudo /sbin/vfcmt add -cache_dev #{@ssd_device}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo /sbin/vfcmt start -cache_dev #{@ssd_device}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo /sbin/vfcmt add -source_dev #{@source_device}"
    @shell.execute(cmd, verbose, true)
    
    cmd = "sudo /sbin/vfcmt start -source_dev #{@source_device}"
    @shell.execute(cmd, verbose, true)
    
    puts "-----vfcache status-----"
    cmd = "sudo /sbin/vfcmt display -all"
    @shell.execute(cmd, verbose)
    puts "------------------------"
  end

  def stop(verbose,status_can_be_nonzero=false)
    puts "----------stopping vfcache----------"

    puts "-----vfcache status-----"
    cmd = "sudo /sbin/vfcmt display -all"
    @shell.execute(cmd, verbose, true)
    puts "------------------------"

    cmd = "sudo umount #{@mount_point}"   
    @shell.execute(cmd,verbose,true)
    
    cmd = "sudo /sbin/vfcmt stop -source_dev #{@source_device}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo /sbin/vfcmt delete -source_dev #{@source_device}"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo /sbin/vfcmt stop -cache_dev /dev/rssda"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo /sbin/vfcmt delete -cache_dev /dev/rssda"
    @shell.execute(cmd, verbose, true)
    
    cmd = "sudo /sbin/vfcmt stop -cache_dev /dev/rssdb"
    @shell.execute(cmd, verbose, true)

    cmd = "sudo /sbin/vfcmt delete -cache_dev /dev/rssdb"
    @shell.execute(cmd, verbose, true)
    
    cmd = "sudo /etc/init.d/SFC stop"
    @shell.execute(cmd, verbose, true)

  end
    
end
