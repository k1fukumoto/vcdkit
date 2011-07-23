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

options={
  :tree => Time.now.strftime('%Y-%m-%d_%H-%M-%S'),
  :dir => "#{$VCDKIT}/data/vcd-dump",
  :target => :all,
}

vcd1 = ['vcd.vhost.ultina.jp','System','vcdadminl']
vcd2 = ['vcd.vcdc.whitecloud.jp','System','vcdadminl']

vsp1 = ['10.127.11.51','vcdadmin']
vsp2 = ['10.128.0.57','vcdadmin']

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-dump.rb [options]"

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
  opt.on('-c','--vcenter HOST,USER',Array,'vCenter login parameters') do |o|
    case o[0]
    when "1"
      options[:vsp] = vsp1
    when "2"
      options[:vsp] = vsp2
    else
      options[:vsp] = o
    end
  end

  opt.on('-A','--all','Dump all data') do |o|
    options[:target] = :all
  end
  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Dump vApp') do |o|
    options[:target] = o
  end
  opt.on('-o','--org ORG',Array,'Dump organization') do |o|
    options[:target] = o
  end

  opt.on('-t','--tree TREENAME',Array,'Directory name to identify dump tree') do |o|
    options[:tree] = o
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
  if (options[:target].nil?)
    raise OptionParser::MissingArgument.new("--target")
  end
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

$log = VCloud::Logger.new(options[:logfile])

begin
  vcd = VCloud::VCD.new
  vcd.connect(*options[:vcd])

  vc = nil
  if (options[:vsp])
    vc = VSphere::VCenter.new
    vc.connect(*options[:vsp])
  end

  ot = options[:target]
  dir = "#{options[:dir]}/#{options[:tree]}"
  if(ot == :all)
    vcd.save(dir)
    vc.save(dir) unless vc.nil?
  elsif(ot.size == 1)
    vcd.org(ot[0]).save(dir)
  elsif(ot.size == 3)
    vcd.org(ot[0]).vdc(ot[1]).vapp(ot[2]).save(dir)
  end
rescue Exception => e
  $log.error("vcd-dump failed: #{e}")
  $log.error(e.backtrace)
  exit 1
end
