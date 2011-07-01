#######################################################################################
#
# Copyright 2011 Kaoru Fukumoto All Rights Reserved
#
# You may freely use and redistribute this script as long as this 
# copyright notice remains intact 
#
#
# DISCLAIMER. THIS SCRIPT IS PROVIDED TO YOU "AS IS" WITHOUT WARRANTIES OR CONDITIONS 
# OF ANY KIND, WHETHER ORAL OR WRITTEN, EXPRESS OR IMPLIED. THE AUTHOR SPECIFICALLY 
# DISCLAIMS ANY IMPLIED WARRANTIES OR CONDITIONS OF MERCHANTABILITY, SATISFACTORY 
# QUALITY, NON-INFRINGEMENT AND FITNESS FOR A PARTICULAR PURPOSE. 
#
#######################################################################################
require 'optparse'
require 'vcdkit'

options = {
  :command => :list
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vm.rb command [options]"
  
  options[:command] = :list
  opt.on('-l','--list','List all virtual machines (default)') do 
    options[:command] = :list
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

optparse.parse!

vcd = VCloud::VCD.new
vcd.load("../VCDDUMP")
#VMExt::VSphere.new(vcd).dump("../VCDDUMP")




