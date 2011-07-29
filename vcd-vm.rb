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
$: << File.dirname(__FILE__) + "/lib"
require 'optparse'
require 'vcdkit'

options = {
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-vm.rb [cmd-options]"
  
  opt.on('-v','--vcd HOST,ORG,USER',Array,'vCD login parameters') do |o|
    case o[0]
    when "1"
      options[:vcd] = $VCD1
    when "2"
      options[:vcd] = $VCD2
    else
      options[:vcd] = o
    end
  end
  opt.on('-c','--vcenter HOST,USER',Array,'vCenter login parameters') do |o|
    case o[0]
    when "1"
      options[:vsp] = $VSP1
    when "2"
      options[:vsp] = $VSP2
    else
      options[:vsp] = o
    end
  end

  opt.on('-a','--vapp ORG,VDC,VAPP',Array,'Target vApp') do |o|
    options[:target] = o
  end

  opt.on('-h','--help','Display this help') do
    puts opt
    exit
  end
end

begin
  optparse.parse!
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

$log = VCloud::Logger.new(options[:logfile])

begin
  vcd = VCloud::VCD.new
  vcd.connect(*options[:vcd])

  ot = options[:target]
  moref = ''
  vcd.org(ot[0]).vdc(ot[1]).vapptemplate(ot[2]).each_vm do |vm|
    moref = vm.moref
  end

  vc = VSphere::VCenter.new
  vc.connect(*options[:vsp])
  vc.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
    dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |cr|
      cr.host.each do |h|
        h.vm.each do |vm|
#          next unless vm.moref == vm._ref
          puts "#{moref} <=> #{vm._ref} #{vm.name}"
        end
      end
    end
  end

rescue Exception => e
  $log.error("vcd-vm.rb failed: #{e}")
  $log.error(e.backtrace)
  exit 1
end






