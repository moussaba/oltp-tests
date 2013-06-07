require File.join(File.dirname(__FILE__),'..','swr_drive.rb')

class SwrShell
  def execute(cmd, verbose=false)
    puts cmd
  end
end

j = SwrDrive.new
j.format("/dev/sdz1","ext3")
puts "--------------------------"
j.partition("/dev/sdz",[10000,2000,1000,1000,1000])
puts "--------------------------"
j.partition("/dev/sdz",[10000])
puts "--------------------------"
