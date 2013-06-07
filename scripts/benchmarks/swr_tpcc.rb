require File.expand_path(File.join(File.dirname(__FILE__),'swr_benchmark_template.rb'))

class SwrTpcc < SwrBenchmarkTemplate

  def update_args
    @args["kill_all"] = ["mysql", "tpcc"]
  end

  def set_benchmark_warmup_time
    @args["short_args"]["r"] = @args["warm_up_time"]
  end

  def set_benchmark_run_time
    @args["short_args"]["l"] = @args["run_time"]
  end

  def warmup(verbose=false)
    make(verbose)
    cmd =  "mysql -u root #{@socket_arg} -e \"select count(*) from order_line\" #{@mysql.dbname};\n"
    cmd += "mysql -u root #{@socket_arg} -e \"select count(*) from customer\" #{@mysql.dbname};\n"
    return timeout_run(cmd,verbose,14400)
  end

  def load(verbose=false)
    if @args["warehouses"] < 100
      step = @args["warehouses"]
    else
      step = 100
    end
    cmd =  "{\n"
    cmd += "DBNAME=#{@mysql.dbname}\n"
    cmd += "WH=#{@args["warehouses"]}\n"
    cmd += "HOST=localhost\n"
    cmd += "STEP=#{step}\n"
    cmd += "#{@args["binary"]} $HOST $DBNAME root \"\" $WH 1 1 $WH >> 1.out &\n"
    cmd += "x=1\n\n"
    cmd += "while [ $x -le $WH ]\n"
    cmd += "do\n"
    cmd += "\techo $x $(( $x + $STEP - 1 ))\n"
    cmd += "\t#{@args["binary"]} $HOST $DBNAME root \"\" $WH 2 $x $(( $x + $STEP - 1 ))  >> 2.out &\n"
    cmd += "\t#{@args["binary"]} $HOST $DBNAME root \"\" $WH 3 $x $(( $x + $STEP - 1 ))  >> 3.out &\n"
    cmd += "\t#{@args["binary"]} $HOST $DBNAME root \"\" $WH 4 $x $(( $x + $STEP - 1 ))  >> 4.out &\n"
    cmd += "\tx=$(( $x + $STEP ))\n"
    cmd += "done\n"
    cmd += "};\n"
    cmd += "rm 1.out 2.out 3.out 4.out\n"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

  def create(verbose=false)
    sleep 10
    cmd =  "mysql -u root #{@socket_arg} -e \"create database #{@mysql.dbname}\";\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["create_table"]};\n"
    cmd += "mysql -u root #{@socket_arg} #{@mysql.dbname} < #{@args["add_fkey_idx"]};\n"
    return timeout_run(cmd,verbose)
  end

  def make(verbose=false)
    if File.exists?(@args["binary"])
      return Array.new
    end
    cmd  = "cd #{@args["src"]};\n"
    cmd += "make clean;\n"
    cmd += "make\n"
    shell = SwrShell.new
    return shell.execute(cmd,verbose)
  end

end