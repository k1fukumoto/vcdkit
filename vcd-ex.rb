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

options={
}

vcd1 = ['vcd.vcdc.whitecloud.jp','System','vcdadminl']
vcd2 = ['tvcd.vcdc.whitecloud.jp','System','vcdadminl']

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-ex.rb [options]"

  opt.on('-v','--vcd HOST,ORG,USER',Array,'vCD login parameters') do |o|
    options[:vcd] = o
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
VCDEX_JOBS  = 
  [
   { :vcd => vcd2,
     :vapps => [
                Target.new('Admin','VCDEX-01'),
                ]
   },
   { :vcd => vcd1,
     :vapps => [
                Target.new('Basic Backup - Admin','VCDEX-BB01'),
                Target.new('Basic - Admin','VCDEX-B01'),
                Target.new('Committed Backup - Admin','VCDEX-CB01'),
                Target.new('Committed - Admin','VCDEX-C01'),
               ]
   },
]

#
# MAIN
#
$log = VCloud::Logger.new(options[:logfile])
FileUtils.mkdir_p(VCDEX_DIR) unless File.exists? VCDEX_DIR

begin
  VCDEX_JOBS.each do |job|
    vcd = VCloud::VCD.new
    vcd.connect(*job[:vcd])
    org = vcd.org(VCDEX_ORG)

    # Get thumbnails from all ESX hosts
    job[:vapps].each do |t|
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
    t = job[:vapps][0]
    vdc = org.vdc(t.vdc)

    vapp = vdc.vapp(t.vapp)
    vcd.wait(vapp.powerOff)

    vapp = vdc.vapp(t.vapp)
    vcd.wait(vapp.undeploy)

    vapp = vdc.vapp(t.vapp)
    vcd.wait(vapp.powerOn)
  end
rescue Exception => e
  $log.error("vcd-ex failed: #{e}")
  $log.error(e.backtrace)
end
