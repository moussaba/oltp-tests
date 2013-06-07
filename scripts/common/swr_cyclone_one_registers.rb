#this class is used for accessing registers on p320 or p420
require File.join(File.dirname(__FILE__),'swr_common.rb')

class SwrCycloneOneRegisters

  def initialize(device_address,drive_num)
    @device_address = device_address
    @drive_num = drive_num
    @j = SwrShell.new
  end

  def restart_firmware
    cmd = "sudo bin/superdm/superdm -M -a -n " + @drive_num.to_s
    stdout, stderr, status, cmd = @j.execute(cmd,false,false,true)
  end

  def unlock_registers()
    #unlock registers
    cmd = "sudo echo f800182c:6fcb1344 > /sys/bus/pci/drivers/mtip32xx/#{@device_address}/write_reg"
    stdout, stderr, status, cmd = @j.execute(cmd,false,false,true)
    #puts "stdout #{stdout} stderr #{stderr} status #{status} cmd #{cmd}"
  end

  def lock_registers()
    #lock registers
    cmd = "sudo echo f800082c:6fcb1344 > /sys/bus/pci/drivers/mtip32xx/#{@device_address}/write_reg"
    stdout, stderr, status, cmd = @j.execute(cmd,false,false,true)
    #puts "stdout #{stdout} stderr #{stderr} status #{status} cmd #{cmd}"
  end

  def set_register(register_address,register_value)
    #write value
    register_address = "f8201" + register_address.to_s
    cmd = "sudo echo #{register_address}:#{register_value} > /sys/bus/pci/drivers/mtip32xx/#{@device_address}/write_reg"
    stdout, stderr, status, cmd = @j.execute(cmd,false,false,true)
    # puts "stdout: #{stdout}"
    # puts "stderr: #{stderr}"
    # puts "status: #{status}"
    # puts "cmd: #{cmd}"
  end

  def get_register(register_address)
    #read data
    register_address = "f8200" + register_address.to_s
    cmd = "sudo echo #{register_address} > /sys/bus/pci/drivers/mtip32xx/#{@device_address}/read_reg"
    stdout, stderr, status, cmd = @j.execute(cmd,false,false,true)
    # puts "stdout: #{stdout}"
    # puts "stderr: #{stderr}"
    # puts "status: #{status}"
    # puts "cmd: #{cmd}"

    #copying data out
    tmp = `cat /sys/bus/pci/drivers/mtip32xx/#{@device_address}/read_reg`
    #puts tmp
    split = tmp.split(":")
    return split[1]
  end

  def get_all
    r = Array.new
    r.push [0x00010,0x00041]
    r.push [0x00130,0x00146]
    r.push [0x00208,0x00338]
    r.push [0x00380,0x0038f]
    r.push [0x00400,0x00449]
    r.push [0x00490,0x004d2]
    r.push [0x00500,0x005f0]
    r.push [0x00700,0x0077f]
    h = Hash.new
    r.each do |a|
      a[0].upto(a[1]) do |i|
        h[i.to_s(16)] = get_register(i.to_s(16))
      end
    end
    return h
  end

#
  def set_all(h)
    #input should be hash of key=reg value=setting
    h.each do |k,v|
      puts "setting register 0x#{k} to 0x#{v}"
      set_register(k,v)
    end
  end

  def print_regs(h)
    h.each do |k,v|
      puts "0x#{k} = 0x#{v}"
    end
  end

  def print_all
    print_regs(get_all)
  end
end
