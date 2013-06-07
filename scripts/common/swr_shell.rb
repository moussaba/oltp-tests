require File.join(File.dirname(__FILE__),'swr_shell_standard.rb')
require File.join(File.dirname(__FILE__),'swr_shell_jruby.rb')

class SwrShell

  def initialize
    if RUBY_PLATFORM == 'java'
      @shell = SwrShellJruby.new
    else
      @shell = SwrShellStandard.new
    end
  end

  # extra layer for easy testing, "safe" classes can use the _no_override
  #  un-safe classes can have the execute method overriden to puts ...
  def execute(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    return execute_no_override(cmd, verbose, status_can_be_nonzero, sudo)
  end

  def execute_no_override(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    return @shell.execute(cmd, verbose, status_can_be_nonzero, sudo)
  end

  def background_execute(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    return @shell.background_execute(cmd, verbose, status_can_be_nonzero, sudo)
  end

  def interactive_execute(cmd, verbose=false, status_can_be_nonzero=false, sudo=false)
    return @shell.interactive_execute(cmd, verbose, status_can_be_nonzero, sudo)
  end

  def wait_for_background_proc
    return @shell.wait_for_background_proc
  end

  def wait_for_interactive_proc(verbose=false, status_can_be_nonzero=false)
    return @shell.wait_for_interactive_proc(verbose, status_can_be_nonzero)
  end

  def stdin(cmd, verbose=false)
    return @shell.stdin(cmd, verbose)
  end

  def stdout
    return @shell.stdout
  end

  def stdout_log
    return @shell.stdout_log
  end

end
