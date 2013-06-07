require File.join(File.dirname(__FILE__),'..','swr_shell.rb')


j = SwrShell.new
puts "=================== verbose = false ===================="
stdout, stderr, status = j.execute("hostname")
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "=================== verbose = true ======================"
stdout, stderr, status = j.execute("hostname",true)
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "----------------------"
# setting status_can_be_nonzero to true
# otherwise we raise...
stdout, stderr, status, cmd = j.execute("notreallyavalidcommandtobeexectuting",true,true)
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "----------------------"
j.background_execute("sleep 2\necho one\nsleep 5 &\necho two",true)
puts "background mode - engaged!"
stdout, stderr, status, cmd = j.wait_for_background_proc
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "----------------------"
j.interactive_execute("irb",true)
puts "interactive mode - engaged!"
j.stdin("foo = 1",true)
b = j.stdout_log
j.stdin("foo += 1",true)
j.stdin("puts foo.to_s",true)
j.stdin("quit",true)

stdout, stderr, status, cmd = j.wait_for_interactive_proc
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "b[#{b}]"

puts "----------------------"
puts "sudo on -- should be root"
stdout, stderr, status, cmd = j.execute("whoami",true,true,true)
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"

puts "----------------------"
puts "sudo off"
stdout, stderr, status, cmd = j.execute("whoami",true,true,false)
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"

puts "=================== status_can_be_nonzero = false ======================"
stdout, stderr, status, cmd = j.execute("notreallyavalidcommandtobeexectuting",true,false)
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"