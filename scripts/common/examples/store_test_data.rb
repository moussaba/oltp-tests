#store_test_data.rb
#stores test data on xavier-4 adding metadata
#written to be compatable with jenkins as well as command line
#requires parameters
# ARGV[0] test name: same as jenkins project name
# ARGV[1] test id: same as jenkins build number
# ARGV[2] file name: name of file to be stored 
require 'rubygems'
require 'json'
require 'rest_client'

class StringIO
  def original_filename
    return File.join("foo.json")
  end
  def content_type
     return 'application/octet-stream'
  end
end

host = "xavier-4.micron.com:9000"
url = "http://" + host + "/categories/test_ruby/runs"

puts "<<=====================================================>>"
puts url

data = Hash.new
data["metadata"] = Hash.new
data["payload"] = File.read(ARGV[2])
data["metadata"]["TestName"] = ARGV[0]
data["metadata"]["TestID"] = ARGV[1]
data["metadata"]["Timestamp"] = Time.now.to_s
data["metadata"]["Host"] = `uname -a`
data["metadata"]["Version"] =  File.read("/etc/redhat-release")


puts "<<=====================================================>>"
puts data.to_json

d = StringIO.new(data.to_json)
response = RestClient.post(url, :datafile => d)
puts "<<=====================================================>>"
puts response
