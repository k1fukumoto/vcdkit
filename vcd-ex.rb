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

#
# Process command args
#
options={
  :vcd => ['vcd.vcdc.whitecloud.jp','System','vcdadmin','Redw00d!'],
}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-ex.rb [options]"

  opt.on('-v','--vcd HOST,ORG,USER,PASS',Array,'vCD login parameters') do |o|
    options[:vcd] = o
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

class Target
  attr_reader :vdc,:vapp

  def initialize(vdc,vapp)
    @vdc = vdc
    @vapp = vapp
  end
end

VCDEX_ORG   = 'Admin'
VCDEX_DIR   = './data/vcd-ex'
VCDEX_TARGETS  = 
  [
   Target.new('Basic - Admin','VCDEX-B01'),
   Target.new('Basic Backup - Admin','VCDEX-BB01'),
   Target.new('Committed - Admin','VCDEX-C01'),
   Target.new('Committed Backup - Admin','VCDEX-CB01'),
   ]

#
# MAIN
#
vcd = VCloud::VCD.new
vcd.connect(*options[:vcd])
org = vcd.org(VCDEX_ORG)

FileUtils.mkdir_p(VCDEX_DIR) unless File.exists? VCDEX_DIR

# Get thumbnails from all ESX hosts
VCDEX_TARGETS.each do |t|
  vapp = org.vdc(t.vdc).vapp(t.vapp)

  if(vapp.status == "Powered Off")
      vcd.wait(vapp.powerOn)
  end

  vapp.each_vm do |vm|
    open("#{VCDEX_DIR}/#{vm.name}.png",'w') do |f|
      f.write vm.thumbnail
    end
  end
end

# Recycle power of one of vApp
t = VCDEX_TARGETS[0]
vapp = org.vdc(t.vdc).vapp(t.vapp)
vcd.wait(vapp.powerOff)
vcd.wait(vapp.undeploy)
vcd.wait(vapp.powerOn)


