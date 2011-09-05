#!/usr/bin/ruby -I./lib
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
require 'pp'

#
# Process command args
#
options = {
  :input => "./data/vcd-dump",
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vapp.rb CMD [cmd-options]"
  
  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    case o[0]
    when "1"
      options[:vcd] = $VCD1
    when "2"
      options[:vcd] = $VCD2
    else
      options[:vcd] = o
    end
  end

  opt.on('-i','--input DIR','Root directory of the vCD dump data') do |o|
    options[:input] = o
  end
  opt.on('-t','--tree TREENAME',Array,'Directory name to identify dump tree') do |o|
    options[:tree] = o
  end
  opt.on('-c','--clone ORG,VDC,VAPP',Array,'Src vApp') do |o|
    options[:src] = o
  end
  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  raise OptionParser::MissingArgument.new("--input") if options[:input].nil?
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

vcd = VCloud::VCD.new()
vcd.connect(*options[:vcd])

src = VCloud::VCD.new().load("#{options[:input]}/#{options[:tree]}",*options[:src])
vcd.wait(vcd.org(options[:src][0]).vdc(options[:src][1]).composeVApp(src,'BACKUPTEST-01R'))
