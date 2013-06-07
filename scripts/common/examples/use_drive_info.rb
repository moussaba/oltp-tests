require File.join(File.dirname(__FILE__),'..','swr_drive_info.rb')

j = SwrDriveInfo.new
puts j.size("/dev/sda","b")
puts "--------------------------"
puts j.size("/dev/sda","K")
puts "--------------------------"
puts j.size("/dev/sda","m")
puts "--------------------------"
puts j.size("/dev/sda","G")
puts "--------------------------"
puts j.size("/dev/sda","T")
puts "--------------------------"

j.print