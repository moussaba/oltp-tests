require "rubygems"
require "open4"
if RUBY_PLATFORM == 'java'
  require 'java'
end

class JRubyProcess
  def popen(cmd)
    # You can't wait for the PID returned by JRuby's IO.popen4, so
    # this is necessary.
    @process = Java::JavaLang::ProcessBuilder.new(cmd.to_java(:string)).start

    [
      # java.util.Process flips the meanings of "in" and "out"
      # relative to popen3
      @process.output_stream.to_io,
      @process.input_stream.to_io,
      @process.error_stream.to_io
    ]
  end

  def wait
    @process.waitFor
  end

  def kill
    @process.destroy
  end

end

class SwrShellJruby

  attr_accessor :stdout, :stderr, :stdin_log, :stdout_log, :stderr_log

  def execute(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    stdout=""
    stderr=""
    if sudo
      shell_cmd = "sudo bash"
    else
      shell_cmd = "bash"
    end
    IO.popen4(shell_cmd) do |pid, si, so, se|
      si.puts(cmd)
      if verbose then puts cmd end
      si.close

      while(line=so.gets)
        stdout+=line
        if verbose then puts line end
      end

      while(line=se.gets)
        stderr+=line
        if verbose then puts line end
      end

      unless stdout.nil?
        stdout=stdout.strip
      end
      unless stderr.nil?
        stderr=stderr.strip
      end

    end

    status = $?

    if status != 0
      if not status_can_be_nonzero
        msg = "shell command failed with exitcode=#{status}\n"
        msg += "cmd=[#{cmd}]\n"
        msg += "stdout=[#{stdout}]\n"
        msg += "stderr=[#{stderr}]\n"
        puts msg
        raise msg
      end
    end
    return stdout, stderr, status, cmd
  end

  def stdin(cmd, verbose=false)
    @stdin_log += cmd + "\n"
    if verbose then puts cmd end
    @stdin.puts cmd
  end

  def interactive_execute(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    @stderr_log = ""
    @stdout_log = ""
    @stdin_log = ""
    if sudo
      shell_cmd = "sudo bash"
    else
      shell_cmd = "bash"
    end
    @jruby_process = JRubyProcess.new
    @stdin, @stdout, @stderr = @jruby_process.popen(shell_cmd)
    stdin(cmd, verbose=false)
    sleep(1)
  end

  def wait_for_interactive_proc(verbose=false, status_can_be_nonzero=false)
    @stdin.close
    wait_for_background_proc_status(@stdin_log, @stdout, @stderr, verbose, status_can_be_nonzero)
    @thread.join
    return @stdout_log, @stderr_log, @status, @cmd
  end

  def background_execute(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    cmd += "&\n echo impossiblyspecifickeyword99883311231ohyeah\n"
    interactive_execute(cmd, verbose, status_can_be_nonzero, sudo)
    @stdin.close
    while(line=@stdout.gets)
      @stdout_log+=line
      if verbose then puts line end
      if line =~ /^impossiblyspecifickeyword99883311231ohyeah/
        break
      end
    end
    wait_for_background_proc_status(@stdin_log, @stdout, @stderr, verbose, status_can_be_nonzero)
  end

  def wait_for_background_proc_status(si, so , se, verbose=false, status_can_be_nonzero=false)
    @thread = Thread.new do
      @status = @jruby_process.wait
      @cmd = si

      while(line=so.gets)
        @stdout_log+=line
        if verbose then puts line end
      end

      while(line=se.gets)
        @stderr_log+=line
        if verbose then puts line end
      end

      if @status != 0
        if not status_can_be_nonzero
          msg = "shell command failed with exitcode=#{@status}\n"
          msg += "cmd=[#{@cmd}]\n"
          msg += "stdout=[#{@stdout}]\n"
          msg += "stderr=[#{@stderr}]\n"
          raise msg
        end
      end
    end
  end

  def wait_for_background_proc
    @thread.join
    @jruby_process.kill
    return @stdout_log, @stderr_log, @status, @cmd
  end

end
