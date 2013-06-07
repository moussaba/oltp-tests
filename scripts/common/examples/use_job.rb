require File.join(File.dirname(__FILE__),'..','swr_job.rb')

j = SwrJob.new(ARGV[0])
puts "---unscrubbed config------------------"
unconfig = YAML::load(File.open(ARGV[0]))
j.print_config(unconfig)
puts "---scrubbed config------------------"
j.print_config(j.config)
puts "---altered config------------------"
j.config["foo"] = "bar"
j.print_config(j.config)
