require File.join(File.dirname(__FILE__),'..','swr_drive_handler.rb')
require 'yaml'

class SwrShell
  def execute(cmd, verbose=false,status_can_be_nonzero=false)
    puts cmd
  end
end

config = YAML::load(File.open(ARGV[0]))

j = SwrDriveHandler.new(config["drives"])

puts "------partition----------"
j.partition(true)
puts "------format----------"
j.format(true)
puts "------mount----------"
j.mount(true)
puts "------link----------"
j.link(true)
puts "------umount----------"
j.umount(true)
puts "------delete----------"
j.delete(true)
puts "------copy_data----------"
j.copy_data(true)