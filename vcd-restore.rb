#!/usr/bin/ruby
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
$: << File.dirname(__FILE__) + "/lib"
require 'optparse'
require 'vcdkit'

#
# Process command args
#
vcd1 = ['vcd.vhost.ultina.jp','System','vcdadminl']
vcd2 = ['vcd.vcdc.whitecloud.jp','System','vcdadmin']

options = {
  :input => "/opt/vmware/vcdkit/data/vcd-dump",
  :output => "/opt/vmware/vcdkit/data/vcd-report",
  :vcd => vcd2
}

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

  opt.on('-o','--output DIR','Specify directory for reports') do |o|
    options[:output] = o
  end

  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Restore source vApp') do |o|
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
  org,vdc,vapp = *options[:src]
  src = VCloud::VApp.new(org,vdc,vapp).load("#{options[:input]}/#{options[:tree]}")

  vcd = VCloud::VCD.new()
  vdc = vcd.connect(*options[:vcd]).org(org).vdc(vdc)
  vdc.vapp(vapp).restore(src)
  vdc.vapp(vapp).saveparam("#{options[:output]}/RESTORE")

rescue Exception => e
  $log.error("vcd-restore failed: #{e}")
  $log.error(e.backtrace)
end
