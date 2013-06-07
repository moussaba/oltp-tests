require File.join(File.dirname(__FILE__),'..','swr_mysqld.rb')

class SwrShell
  def execute(cmd, verbose=false, status_can_be_nonzero=false)
    puts cmd
  end
end


a = Hash.new
a["datadir"] = "/tmp/foo/data"
a["innodb_buffer_pool_size"] = "1GB"
a["innodb_data_home_dir"] = "/tmp/foo/log"
a["innodb_log_group_home_dir"] = "/tmp/foo/log"

j = SwrMysqld.new("mysqlbin","foo",a,"","tpcc")
j.start(true)
j.warmup(true)
j.shutdown(true)