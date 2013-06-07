require File.join(File.dirname(__FILE__), 'swr_shell.rb')

class SwrFileUtils

  def arbitrary_unix_command(cmd,verbose=false)
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def method_missing(method_name,*args)
    meth = method_name.to_s
    cmd = ""
    if meth =~ /^su_/
      cmd += "sudo "
      meth.gsub!(/^su_/,"")
    end
    cmd += meth.gsub(/_/," -")
    if args[-1].class == TrueClass
      verbose = args.pop
    else
      verbose = false
    end
    cmd += " #{args.join(" ")}"
    return arbitrary_unix_command(cmd,verbose)
  end

end