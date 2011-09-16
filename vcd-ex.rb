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

options={}

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-ex.rb [options]"

  vcdopts(options,opt)

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
rescue SystemExit => e
  exit(e.status)
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

VCDEX_DIR   = './data/vcd-ex'
VCDEX_ORG   = 'Admin'
VCDEX_JOBS  = {
  $VCD[0] => [
           Target.new('Basic Backup - Admin','VCDEX-BB01'),
           Target.new('Committed Backup - Admin','VCDEX-CB01'),
           Target.new('Basic - Admin','VCDEX-B01'),
           Target.new('Committed - Admin','VCDEX-C01'),
          ],
  $VCD[1] => [
           Target.new('Basic Backup - Admin','VCDEX-BB01'),
           Target.new('Committed Backup - Admin','VCDEX-CB01'),
          ],
  $VCD[2] => [
           Target.new('Admin','VCDMON-01'),
          ],
}

#
# MAIN
#
$log = VCloud::Logger.new(options[:logfile])
FileUtils.mkdir_p(VCDEX_DIR) unless File.exists? VCDEX_DIR

begin
  vcd = VCloud::VCD.new
  vcd.connect(*options[:vcd])
  org = vcd.org(VCDEX_ORG)

  # Get thumbnails from all ESX hosts
  VCDEX_JOBS[options[:vcd]].each do |t|
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
  t = VCDEX_JOBS[options[:vcd]][0]
  vdc = org.vdc(t.vdc)

  vapp = vdc.vapp(t.vapp)
  vcd.wait(vapp.powerOff)

  vapp = vdc.vapp(t.vapp)
  vcd.wait(vapp.undeploy)

  vapp = vdc.vapp(t.vapp)
  vcd.wait(vapp.powerOn)

rescue Exception => e
  $log.error("vcd-ex failed: #{e}")
  $log.error(e.backtrace)
end
