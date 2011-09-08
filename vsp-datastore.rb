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

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-datastore.rb [options]"

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
rescue SystemExit => e
  exit(e.status)
rescue Exception => e
  puts e
  puts optparse
  exit 1
end

$log = VCloud::Logger.new(options[:logfile])

begin
  vc = VSphere::VCenter.new
  vc.connect(*options[:vsp])

  esxpass = VCloud::SecurePass.new().decrypt(File.new('.esx','r').read)

  vc.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
    dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |c|
      c.host.each do |h|
        esx = VSphere::VCenter.new
puts h.name
        esx.connect(h.name,'root',esxpass)
        fm = esx.scon.fileManager
        esx.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
          dc.datastore.each do |ds|
            dspath = "[#{ds.name}] VCDKIT_TMPDIR"
            $log.info("Test datastore access #{h.name} >> #{ds.name}")
#            fm.MakeDirectory('name' => dspath)
#            fm.DeleteDatastoreFile_Task('name' => dspath).wait_for_completion
          end
        end
      end
    end
  end
  
rescue Exception => e
  $log.error("vcd-datastore failed: #{e}")
  $log.error(e.backtrace)
  exit 1
end
