#!/usr/bin/ruby -I ./lib
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

#
# Process command args
#
options = {
  :command => nil,
  :dir => nil,
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vm.rb CMD [cmd-options]"
  
  opt.on('-l','--list','CMD: List all virtual machines (default)') do 
    options[:command] = :list
  end

  opt.on('-d','--dir DIR','Specify root directory of the dump data') do |o|
    options[:dir] = o
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  raise OptionParser::MissingArgument.new("CMD") if options[:command].nil?
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

#
# MAIN
#
vcd = VCloud::VCD.new
vcd.load(options[:dir])

ERB.new(File.new("template/vcd-vm_csv.erb").read,0,'>').run






