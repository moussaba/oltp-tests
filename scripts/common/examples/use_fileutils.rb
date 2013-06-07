require File.join(File.dirname(__FILE__),'..','swr_file_utils.rb')

class SwrShell
  def execute(cmd, verbose=false)
    puts cmd
  end
end


j = SwrFileUtils.new

j.ln_s("ff","lll",true)
j.su_ln_s("ff","lll",true)

j.ln_s "aaa", "bbb"