require File.join(File.dirname(__FILE__), 'swr_shell.rb')

class SwrDriveInfo

  def sectors_to_unit(sectors, unit)
    m = 512.0
    if ["b","B"].include?(unit)
      m = m / 1
    elsif ["k","K"].include?(unit)
      m = m / (1000)
    elsif ["m","M"].include?(unit)
      m = m / (1000000)
    elsif ["g","G"].include?(unit)
      m = m / (1000000000)
    elsif ["t","T"].include?(unit)
      m = m / (1000000000000)
    elsif ["p","P"].include?(unit)
      m = m / (1000000000000000)
    else
      m = 1
    end
    size = sectors * m
    if size == 0
      return size
    elsif size.to_i / size > 0.8
      return size.to_i
    end
    return size
  end

  def size(dev,unit=nil)
    d = dev.split("/").pop
    cmd = "cat /sys/block/#{d}/size"
    shell = SwrShell.new
    so, se = shell.execute_no_override(cmd)
    sectors = so.to_i
    return sectors_to_unit(sectors, unit)
  end

  def blockdevs
    devs = Array.new
    Dir.foreach("/sys/block/") do |f|
      if f =~ /^ram/ or f =~ /^loop/ or f =~ /^\./ then next end
      devs.push "/dev/" + f
    end
    return devs.sort
  end

  def model(dev)
    d = dev.split("/").pop
    if d =~ /^rssd/
      return "Micron P320 assumed"
    end
    cmd = "cat /sys/block/#{d}/device/model"
    shell = SwrShell.new
    so, se = shell.execute_no_override(cmd,false,true)
    return so
  end

  def mounts(blockdev)
    m = Array.new
    shell = SwrShell.new
    so, se = shell.execute_no_override("sudo df")
    so.each_line do |line|
      if line =~ /^#{blockdev}/
        a = line.split()
        m.push Hash[ a[0] => a[5] ]
      end
    end
    return m
  end

  def partitions(dev)
    parts = Array.new
    shell = SwrShell.new
    so, se = shell.execute_no_override("sudo cat /proc/partitions")
    so.each_line do |line|
      d = dev.split("/").pop
      a = line.split()
      if a[3] =~ /^#{d}/ and a[3] != d
        sectors = a[2].to_i / 2
        parts.push Hash[ a[3] => sectors ]
      end
    end
    return parts
  end

  def dev_info(dev)
    h = Hash.new
    h[:size] = size(dev)
    h[:model] = model(dev)
    h[:mounts] = mounts(dev)
    h[:parts] = partitions(dev)
    return h
  end

  def str_format_dev(dev)
    h = dev_info(dev)
    size = sectors_to_unit(h[:size],"G")

    mnts = ""
    if h[:mounts].length != 0
      a = Array.new
      h[:mounts].each do |q|
        q.each {|k,v| a.push "#{k} => #{v}"}
      end
      mnts += "[" + a.join(",") + "]"
    end

    parts = ""
    if h[:parts].length != 0
      a = Array.new
      h[:parts].each do |q|
        q.each {|k,v| a.push "#{k} => #{sectors_to_unit(v,"G")}G"}
      end
      parts += "[" + a.join(",") + "]"
    end

    return "#{dev}, #{h[:model]}, #{size}G, #{parts}, #{mnts}"
  end

  def print_dev(dev)
    puts str_format_dev(dev)
  end

  def print
    blockdevs.each do |dev|
      print_dev(dev)
    end
  end

end
