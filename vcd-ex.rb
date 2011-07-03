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
  :vcd => ['vcd.vhost.ultina.jp','System','vcdadminl','Redw00d!'],
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

#
# MAIN
#
vcd = VCloud::VCD.new
vcd.connect(*options[:vcd])
vapp = vcd.org('Admin').vdc('Admin').vapp('VCDMON-01')

vapp.each_vm do |vm|
  if(vm.status == "Powered Off")
    puts "*** Powering on #{vm.name} (#{vm.status}) ***"
    vcd.wait(vm.powerOn)
  end

  open("#{vm.name}.png",'w') do |f|
    f.write vm.thumbnail
  end
end

3.times do |i|
  target = "DUMMY-0#{1 + rand(8)}"

  vm = vapp.vm(target)
  puts "*** Powering off #{target} (#{vm.status}) ***"
  vcd.wait(vm.powerOff)

  vm = vapp.vm(target)
  puts "*** Powering On #{target} (#{vm.status})***"
  vcd.wait(vm.powerOn)
end
