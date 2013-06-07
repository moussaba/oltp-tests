require File.expand_path(File.join(File.dirname(__FILE__),'..','scripts','common','swr_common.rb'))

drive_number = ENV["DRIVE_NUMBER"]

j = SwrShell.new
puts "----- secure erase drive number = '#{drive_number}' -----"
stdout, stderr, status, cmd = j.interactive_execute("sudo bin/superdm/superdm -X -p ffff -n #{drive_number}",true,true,false)
tout = Thread.new do
  c = 0
  while(true)
    sleep(0.1)
    a = j.stdout_log.split("\n")
    if not a.length > c
      next
    end
    (a.length - c).times do |i|
      puts a[c + i]
    end
    c += 1
  end
end
terr = Thread.new do
  c = 0
  while(true)
    sleep(0.1)
    a = j.stderr_log.split("\n")
    if not a.length > c
      next
    end
    (a.length - c).times do |i|
      puts a[c + i]
    end
    c += 1
  end
end
sleep(1)
j.stdin("Y",true)
stdout2, stderr2, status2, cmd2 = j.wait_for_interactive_proc
tout.kill
terr.kill
puts "cmd[#{cmd2}]"
puts "stdout[#{stdout2.chomp}]"
puts "stderr[#{stderr2.chomp}]"
puts "status[" + status2.to_s + "]"

# puts "----- low level format drive number = '#{drive_number}' -----"
# stdout, stderr, status, cmd = j.interactive_execute("sudo bin/superdm/superdm -X -L -n #{drive_number}",true,true,false)
# tout = Thread.new do
#   c = 0
#   while(true)
#     sleep(0.1)
#     a = j.stdout_log.split("\n")
#     if not a.length > c
#       next
#     end
#     (a.length - c).times do |i|
#       puts a[c + i]
#     end
#     c += 1
#   end
# end
# terr = Thread.new do
#   c = 0
#   while(true)
#     sleep(0.1)
#     a = j.stderr_log.split("\n")
#     if not a.length > c
#       next
#     end
#     (a.length - c).times do |i|
#       puts a[c + i]
#     end
#     c += 1
#   end
# end
# sleep(1)
# j.stdin("Y",true)
# stdout2, stderr2, status2, cmd2 = j.wait_for_interactive_proc
# tout.kill
# terr.kill
# puts "cmd[#{cmd2}]"
# puts "stdout[#{stdout2.chomp}]"
# puts "stderr[#{stderr2.chomp}]"
# puts "status[" + status2.to_s + "]"
