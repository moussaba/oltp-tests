require File.join(File.dirname(__FILE__),'..','swr_ssh.rb')

if ARGV.length != 3
  puts "Must have 3 arguments 'host, username, password' for a valid ssh server."
  exit
end

j = SwrSsh.new(ARGV[0], ARGV[1], ARGV[2])

puts "=================== verbose = false ===================="
stdout, stderr, status = j.execute("hostname")
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "----------------------"
stdout, stderr, status, cmd = j.execute("notreallyavalidcommandtobeexectuting")
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "=================== verbose = true ======================"
stdout, stderr, status = j.execute("hostname",true)
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
puts "----------------------"
stdout, stderr, status, cmd = j.execute("notreallyavalidcommandtobeexectuting",true)
puts "cmd[#{cmd}]"
puts "stdout[#{stdout.chomp}]"
puts "stderr[#{stderr.chomp}]"
puts "status[" + status.to_s + "]"
