require File.expand_path(File.join(File.dirname(__FILE__),'..','swr_job.rb'))

j = SwrJob.new(ARGV)
ARGV.each do |arg|
  puts"---print #{arg}------------------"
  j.print_config(YAML::load(File.open(arg)))
end
puts "---print config------------------"
j.print_config(j.config)
