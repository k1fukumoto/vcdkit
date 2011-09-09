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

  opt.on('-C','--conf CONFFILE','Configuration file name') do |o|
    options[:conf] = o
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
$testrun = true
$esxpass = VCloud::SecurePass.new().decrypt(File.new('.esx','r').read)

def each_datastore(fm,ds)
  dspath = "[#{ds.name}] VCDKIT_TMPDIR"
  $log.info("Test datastore access: Datastore Path '#{dspath}'")
  begin
    # ensure no left-overs from the last run
    unless ($testrun)
      fm.DeleteDatastoreFile_Task('name' => dspath).wait_for_completion
    end
  rescue Exception => e
  end
  unless ($testrun)
    fm.MakeDirectory('name' => dspath)
    fm.DeleteDatastoreFile_Task('name' => dspath).wait_for_completion
  end
end

def each_esx(hostname,datastores=nil)
  esx = VSphere::VCenter.new
  esx.connect(hostname,'root',$esxpass)

  fm = esx.scon.fileManager
  $log.info("Test datastore access: ESX '#{esx.name}'")
  esx.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
    if (datastores.nil?)
      dc.datastore.each do |ds|
        each_datastore(fm,ds)
      end
    else
      datastores.each do |dsname|
        ds = dc.find_datastore(dsname)
        if(ds.nil?)
          raise "Datastore '#{dsname}' cannot be found"
        else
          each_datastore(fm,ds)
        end
      end
    end
  end
end

begin
  if(options[:conf])
    conf = REXML::Document.new(File.new(options[:conf],'r').read)
    ds = conf.elements.collect('//dslist/datastore') {|n| n.text}
    conf.elements.each('//dslist/esx') do |h|
      each_esx(h.text,ds)
    end
  else
    vc = VSphere::VCenter.new
    vc.connect(*options[:vsp])
    vc.root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
      dc.hostFolder.childEntity.grep(RbVmomi::VIM::ComputeResource).each do |c|
        c.host.each do |h|
          each_esx(h.name)
        end
      end
    end
  end
rescue Exception => e
  $log.error("vsp-datastore failed: #{e}")
  $log.error(e.backtrace)
  exit 1
end
