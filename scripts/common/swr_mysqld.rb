require File.join(File.dirname(__FILE__), 'swr_shell.rb')

class SwrMysqld

  attr_accessor :args

  def initialize(args)
    @args = args
    if @args["named_args"] == nil
      @socket_arg = ""
    elsif @args["named_args"]["socket"] == nil
      @socket_arg = ""
    else
      @socket_arg = " --socket=#{@args["named_args"]["socket"]} "
    end
  end

  def socket
    return @args["named_args"]["socket"]
  end

  def dbname
    return @args["dbname"]
  end

  def process_named_args(named_args)
    s = ""
    if named_args == nil
      return s
    end
    named_args.each do |k,v|
      s += " --#{k}=#{v.to_s}"
    end
    return s
  end

  def process_short_args(short_args)
    s = ""
    if short_args == nil
      return s
    end
    short_args.each do |k,v|
      s += " -#{k} #{v.to_s}"
    end
    return s
  end

  def process_unnamed_args(unnamed_args)
    s = ""
    if unnamed_args == nil
      return s
    end
    unnamed_args.each do |v|
      s += " #{v.to_s}"
    end
    return s
  end

  def start(verbose=false)
    #Ubuntu Hack, /var/run/mysqld does not exist and needs to be created
    #see mysqld_safe
    cmd = "sudo mkdir -p /var/run/mysqld"
    myshell = SwrShell.new
    myshell.execute(cmd,verbose)
    
    cmd = "sudo #{@args["binary"]} "
    cmd += process_named_args(@args["named_args"])
    cmd += process_short_args(@args["short_args"])
    cmd += process_unnamed_args(@args["unnamed_args"])
    cmd += " #{@args["extra_args"]} "
    #cmd += " 2>&1 | tee /tmp/swr_mysqld.log "
    #puts "cmd<<#{cmd}>>"
    @mysql = SwrShell.new
    return @mysql.background_execute(cmd,verbose)
  end

  def shutdown(verbose=false)
    #drain_dirty_pages(verbose)
    cmd = "mysqladmin -u root #{@socket_arg} shutdown;\n"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def wait
    return @mysql.wait_for_background_proc
  end

  def innodb_stats(verbose=false)
    
    cmd = "mysql -u root -e \"show engine innodb status\\G\""
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def drain_dirty_pages(verbose=false)
    stdout = ""
    stderr = ""
    status = 0
    cmdline = ""

    cmd  = "{\n"
    cmd += "\toldwt=0\n"
    cmd += "\twhile [ true ]\n"
    cmd += "\tdo\n"
    cmd += "\t\tmysql -u root #{@socket_arg} -e \"set global innodb_max_dirty_pages_pct=0\" #{dbname}\n"
    cmd += "\t\twt=`mysql -u root #{@socket_arg} -e \"SHOW ENGINE INNODB STATUS\\G\" | grep \"Modified db pages\" | sort -u | awk '{print $4}'`\n"
    cmd += "\t\techo old mysql pages $oldwt\n"
    cmd += "\t\techo \"mysql pages $wt\"\n"
    cmd += "\t\tif [[ \"$wt\" -lt 100 ]] ;\n"
    cmd += "\t\tthen\n"
    cmd += "\t\t\tmysql -u root #{@socket_arg} -e \"set global innodb_max_dirty_pages_pct=90\" #{dbname}\n"
    cmd += "\t\t\tbreak\n"
    cmd += "\t\telse\n"
    cmd += "\t\t\tif [[ \"$wt\" -eq \"$oldwt\" ]] ; then\n"
    cmd += "\t\t\t\techo Breaking with flush interrupted $wt $oldwt\n"
    cmd += "\t\t\t\tbreak\n"
    cmd += "\t\t\telse\n"
    cmd += "\t\t\t\toldwt=$wt\n"
    cmd += "\t\t\tfi\n"
    cmd += "\t\tfi\n"
    cmd += "\t\tsleep 10\n"
    cmd += "\tdone\n"
    cmd += "}\n"

    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def kill_all(verbose=false,status_can_be_nonzero=true)
    return kill_all_existing(verbose,status_can_be_nonzero)
  end

  def kill_all_existing(verbose=false,status_can_be_nonzero=true)
    shell = SwrShell.new
    so, se = shell.execute_no_override("ps aux | grep mysqld")
    so.each_line do |l|
      pid = l.split[1]
      cmd = "sudo kill -9 #{pid}"
      shell.execute(cmd,verbose,status_can_be_nonzero)
    end
  end

end
