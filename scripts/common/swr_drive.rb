require File.join(File.dirname(__FILE__), 'swr_shell.rb')

class SwrDrive

  def format(partition, fstype, extra_args="", verbose=false, label="test_drive")
    if fstype == nil or partition == nil then raise "bad args" end
    if verbose then puts "formatting partition #{partition} as #{fstype}" end
    cmd = "sudo /sbin/mkfs.#{fstype} #{extra_args} -L /#{label} #{partition}"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end
  
  def create_sfdisk_input(parts, ids)
    # a bit of a mess right now
    # partition sizes are specified in MB
    # there is an issue with starting partitions on other than 4k boundaries
    # there are warning messages that say partitions aren't ending on cylinder boundaries
    # so now converting MB to cylinders 56 sectors per cylinder sectors are 512 bytes
    # to add to the joy it didn't see that the -uC command line option works right but the -uS one does
    # so converting cylinders to sectors now and setting drive up using -uS
    # things should be happy but still get warning that partition isn't ending on cylinder boundaries
    # need to come back to this.
    # initially first 63 sectors are used, since we are basing this on cylinders we start at cylinder 2 (sector 112)

    last_partition_end = 1 #partition_start will become cylinder 2 on first partition
    s = ""
    parts.each_index do |i|
      if ids[i] == nil
        id = "83"
      else
        id = ids[i]
      end
      #1048576 byte in a megabyte
      #512 bytes in a sector
      #56 sectors in a cylinder
      partition_byte_size = parts[i] * 1048576    #converting megabytes into bytes
      partition_cylinder_size = partition_byte_size / 28672 #converting bytes to cylinders
      partition_start = last_partition_end + 1
      sector_start = partition_start * 56 #having problems with -uC so going back to -uS
      sector_size = (partition_cylinder_size * 56) 
      last_partition_end = partition_start + partition_cylinder_size - 1 #last_partition_end should match sfdisk 'end' number
      puts "sector start is #{sector_start} and sector size is #{sector_size}"
      s += "echo #{sector_start}, #{sector_size}, #{id}, -,\n"
    end
    return s
  end

# parts - array of partition size in megabytes, only works for up to 4 partitions
# dev - ie /dev/sda not /dev/sda1
  def partition(dev, parts, verbose=false, ids=Array.new)
    if dev == nil or parts == nil then raise "bad args" end
    if verbose
      parts.each_index do |i|
        puts "creating partition #{i} size #{parts[i]}MB"
      end
    end
    input = create_sfdisk_input(parts, ids)

    #get the size of the drive
    cmd = "{\n #{input} } | sudo /sbin/sfdisk -uS --force #{dev}; sleep 5;"
    puts cmd
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def mount(part,path,extra_args="",verbose=false)
    cmd = "sudo mount #{extra_args} #{part} #{path}"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def umount(path,verbose=false,status_can_be_nonzero=false)
    puts "path to unmount is #{path}"
    cmd = "sudo umount #{path}"
    shell = SwrShell.new
    return shell.execute(cmd,verbose,status_can_be_nonzero)
  end

end