#ruby swr_get_all_registers.rb "0000\:41\:00.0"
#a device address looks like this: "0000\:41\:00.0"

require File.expand_path(File.join(File.dirname(__FILE__),'..','common','swr_registers.rb'))

device_address = ARGV[0]

drive = Registers.new(device_address)
drive.unlock_registers()

0x00010.upto(0x00041){|register_address| drive.get_register( register_address.to_s(16))} 
0x00130.upto(0x00146){|register_address| drive.get_register( register_address.to_s(16))} 
0x00208.upto(0x00338){|register_address| drive.get_register( register_address.to_s(16))} 
0x00380.upto(0x0038f){|register_address| drive.get_register( register_address.to_s(16))} 
0x00400.upto(0x00449){|register_address| drive.get_register( register_address.to_s(16))} 
0x00490.upto(0x004d2){|register_address| drive.get_register( register_address.to_s(16))} 
0x00500.upto(0x005f0){|register_address| drive.get_register( register_address.to_s(16))} 
0x00700.upto(0x0077f){|register_address| drive.get_register( register_address.to_s(16))} 

drive.lock_registers()
