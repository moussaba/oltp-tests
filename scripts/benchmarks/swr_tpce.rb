require File.expand_path(File.join(File.dirname(__FILE__),'swr_benchmark_template.rb'))

class SwrTpce < SwrBenchmarkTemplate

  def update_args
    @args["kill_all"] = ["mysql", "tpce"]
  end

  def set_benchmark_warmup_time
    @args["short_args"]["r"] = @args["warm_up_time"]
  end

  def set_benchmark_run_time
    @args["short_args"]["t"] = @args["run_time"]
  end

  def warmup(verbose=false)
    return true
  end

  def create(verbose=false)
  end

  def load(verbose=false)
    retval = Array.new
    retval.push start(verbose)
    puts "DB NAME "
    puts @mysql.dbname
    cmd  = "cd #{@args["src"]};\n"
    cmd += "cd scripts/mysql;\n"
    #cmd +=  "mysql -u root #{@socket_arg} -e \"drop database #{@mysql.dbname}\";\n"
    cmd +=  "mysql -u root #{@socket_arg} -e \"create database #{@mysql.dbname}\";\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["create_table"]};\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["load_data"]};\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["create_index"]};\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["create_fk"]};\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["create_sequence"]};\n"
    shell = SwrShell.new
    retval.push shell.execute(cmd,verbose)
    return retval
  end

  def make(verbose=true)
    if File.exists?(@args["binary"])
      return Array.new
    end
    cmd  = "cd #{@args["src"]};\n"
    cmd += "cd prj;cp Makefile.new Makefile;\n"
    cmd += "make clean;\n"
    cmd += "make 2> /dev/null\n"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

end
