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

options = {
}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcd-mail.rb [cmd-options]"
  
  opt.on('-a','--attachment FILE','Specify attached file name') do |o|
    options[:attachment] = o
  end

  VCloud::Logger.parseopts(opt)
  VCloud::Mailer.parseopts(opt)

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

vcdhost = ''
hostname = `hostname`.chomp
now = Time.now
f = options[:attachment]
$mail.send({f => File.read(a)},binding)

exit($log.errors + $log.warns)
