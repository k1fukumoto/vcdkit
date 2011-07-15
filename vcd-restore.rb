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

vcd1 = ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!']
vcd2 = ['vcd.vcdc.whitecloud.jp','System','vcdadmin','Redw00d!']

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vapp.rb CMD [cmd-options]"
  
  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    case o[0]
    when "1"
      options[:vcd] = vcd1
    when "2"
      options[:vcd] = vcd2
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
  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Restore target vApp') do |o|
    options[:src] = o
  end

  opt.on('-l','--logfile LOGFILEPATH','Log file name') do |o|
    options[:logfile] = o
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
  raise OptionParser::MissingArgument.new("--input") if options[:input].nil?
rescue SystemExit
  exit
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

#
# MAIN
#
$log = VCloud::Logger.new(options[:logfile])

begin
  vcd = VCloud::VCD.new()
  vcd.connect(*options[:vcd])

  vcd.org(options[:src][0]).vdc(options[:src][1]).vapp(options[:src][2]).
    restore(VCloud::VCD.new().load("#{options[:input]}/#{options[:tree]}",*options[:src]))
rescue Exception => e
  $log.error("vcd-restore failed: #{e}")
  $log.error(e.backtrace)
end
