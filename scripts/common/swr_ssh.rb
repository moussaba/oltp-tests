require "rubygems"
require "net/ssh"

class SwrSsh

  def initialize(host, user, password, timeout=5)
    @ssh = Net::SSH.start(host, user, :password => password, :paranoid => false, :timeout => timeout)
  end

  def execute(cmd, verbose=false, status_can_be_nonzero=false,preamble="")
    stdout = ""
    stderr = ""
    status = ""

    # open a new channel and configure a minimal set of callbacks, then run
    # the event loop until the channel finishes (closes)
    channel = @ssh.open_channel do |ch|
      ch.exec "#{cmd}" do |ch, success|
        raise "could not execute command #{cmd}" unless success

        # "on_data" is called when the process writes something to stdout
        ch.on_data do |c, data|
          stdout+=data
          data.each do |d|
            if verbose then puts "#{preamble}#{d}" end
          end
        end

        # "on_extended_data" is called when the process writes something to stderr
        ch.on_extended_data do |c, type, data|
          stderr+=data
          if verbose then puts "#{preamble}#{data}" end
        end

        #exit code 
        #http://groups.google.com/group/comp.lang.ruby/browse_thread/thread/a806b0f5dae4e1e2
        channel.on_request("exit-status") do |ch, data|
          exit_code = data.read_long
          status=exit_code
        end

        channel.on_request("exit-signal") do |ch, data|
          puts "SIGNAL: #{data.read_long}"
        end

        ch.on_close {}
      end
    end

    channel.wait

    if status != 0
      if not status_can_be_nonzero
        msg = "shell command failed with exitcode=#{status}\n"
        msg += "cmd=[#{cmd}]\n"
        msg += "stdout=[#{stdout}]\n"
        msg += "stderr=[#{stderr}]\n"
        raise msg
      end
    end

    return stdout, stderr, status, cmd
  end

end
