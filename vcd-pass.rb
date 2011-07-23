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
require 'rubygems'
require 'highline/import'
require 'optparse'
require 'vcdkit'

options = {:apps => [],:logfile =>"#{$VCDKIT}/logs/vcd-pass.log"}
optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-pass.rb [options]"

  opt.on('-v','--vcd','Change login password for vCloud Director') do |o|
    options[:apps] << {:name => 'vCloud Director', :file => '.vcd'}
  end
  opt.on('-c','--vcenter','Change login password for vCenter') do |o|
    options[:apps] << {:name => 'vCenter', :file => '.vc'}
  end
  opt.on('-b','--chargeback','Change login password for vCenter Chargeback') do |o|
    options[:apps] << {:name => 'vCenter Chargeback', :file =>'.vcb'}
  end
  opt.on('-l','--logfile LOGFILEPATH','Log file name') do |o|
    options[:logfile] = o
  end

  opt.on('-h','--help','Display this help') do
    puts optparse
    exit
  end
end

begin
  optparse.parse!
  if (options[:apps].size == 0)
    raise OptionParser::MissingArgument.new("Applications")
  end
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

$log = VCloud::Logger.new(options[:logfile])
options[:apps].each do |a|
  p = ask("Enter #{a[:name]} password: "){|q| q.echo = '*'}
  open(a[:file],'w'){|f| f.puts VCloud::SecurePass.new().encrypt(p)}
  $log.warn("Password for #{a[:name]} has been changed")
end
