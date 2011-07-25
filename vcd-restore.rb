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
require 'rubygems'
require 'highline/import'
require 'optparse'
require 'vcdkit'

#
# Process command args
#
vcd1 = ['vcd.vhost.ultina.jp','System','vcdadminl']
vcd2 = ['vcd.vcdc.whitecloud.jp','System','vcdadminl']

options = {
  :input => "#{$VCDKIT}/data/vcd-dump",
  :output => "#{$VCDKIT}/data/vcd-report",
  :vcd => vcd2
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vapp.rb CMD [cmd-options]"
  
  opt.on('-v','--vcd HOST,ORG,USER',Array,'vCD login parameters') do |o|
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
rescue SystemExit
  exit
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

$log = VCloud::Logger.new(options[:logfile])

if(options[:tree].nil?)
  choose do |menu|
    menu.header = 'Select restart target directory'
    Dir.glob("#{options[:input]}/*").each do |d|
      next unless File.directory?(d)
      tree = File.basename(d)
      menu.choice(tree) {options[:tree] = tree}
    end
  end

  options[:src] = [nil,nil,nil]
  choose do |menu|
    menu.header = 'Select organization'
    Dir.glob("#{options[:input]}/#{options[:tree]}/ORG/*").each do |d|
      next unless File.directory?(d)
      org = File.basename(d)
      menu.choice(org) {options[:src][0] = org}
    end
  end

  choose do |menu|
    menu.header = 'Select VDC'
    Dir.glob("#{options[:input]}/#{options[:tree]}/" +
             "ORG/#{options[:src][0]}/VDC/*").each do |d|
      next unless File.directory?(d)
      vdc = File.basename(d)
      menu.choice(vdc) {options[:src][1] = vdc}
    end
  end

  choose do |menu|
    menu.header = 'Select VAPP'
    Dir.glob("#{options[:input]}/#{options[:tree]}/" +
             "ORG/#{options[:src][0]}/VDC/#{options[:src][1]}/VAPP/*").each do |d|
      next unless File.directory?(d)
      vapp = File.basename(d)
      menu.choice(vapp) {options[:src][2] = vapp}
    end
  end
end

class NoChangesException < Exception
end

$log.info("[RESTORE OPTIONS]: #{options.to_yaml}")
begin
  org,vdc,vapp = *options[:src]
  vappdir = "ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}"
  diff1 = "'#{options[:output]}/#{options[:tree]}/#{vappdir}'"
  diff2 = "'#{options[:output]}/RESTORE/#{vappdir}'"

  src = VCloud::VApp.new(org,vdc,vapp).load("#{options[:input]}/#{options[:tree]}")

  vcd = VCloud::VCD.new()
  vdc = vcd.connect(*options[:vcd]).org(org).vdc(vdc)

  vdc.vapp(vapp).saveparam("#{options[:output]}/RESTORE")
  ds = %x(diff -cbr #{diff1} #{diff2})
  $log.info("[DIFF BEFORE RESTORE]: >>#{ds}<<")
  if(ds == '')
    print "No differences are found. Continue (yN)? "; a = gets
    raise NoChangesException.new unless (a =~ /yY/)
  end

  vdc.vapp(vapp).restore(src)
  vdc.vapp(vapp).saveparam("#{options[:output]}/RESTORE")
  ds = %x(diff -cbr #{diff1} #{diff2})
  $log.info("[DIFF AFTER RESTORE]: >>#{ds}<<")

rescue NoChangesException => e
  $log.info("vcd-restore operation aborted: No changes to restore.")
rescue Exception => e
  $log.error("vcd-restore failed: #{e}")
  $log.error(e.backtrace)
end
