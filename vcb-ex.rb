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
require 'vcb'

options={}

$log = VCloud::Logger.new
$mail = VCloud::Mailer.new

optparse = OptionParser.new do |opt|
  opt.banner = "Usage: vcb-ex.rb [options]"

  vcbdbopts(options,opt)

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

begin
  vcbdb = Chargeback::VCBDB.new
  vcbdb.connect(*options[:vcbdb])

  DCTS =<<EOS
SELECT server_property_value
FROM cb_server_property
WHERE server_property_name like '<%= key %>'
EOS

  now = Time.now

  ['vmijob.lastProcessTime',
   'cbEventListRawView.lastProcessTime',
   'vcLastProcessTime-%'].each do |key|
    sql = ERB.new(DCTS).result(binding)
    vcbdb.conn.exec(sql) do |r|
      ts = Time.at(Integer(r[0])/1000)
      diff = now - ts
      t = ts.strftime('%Y/%m/%d %H:%M:%S')
      if(diff > 5400)
        $log.error("#{t}: #{diff.to_i}: #{key}")
      else
        $log.info("#{t}: #{diff.to_i}: #{key}")
      end
    end
  end


rescue Exception => e
  $log.error("vcb-ex failed: #{e}")
  $log.error(e.backtrace)

ensure
  if($log.errors>0 && $log.temp)
    # following local variables can be accessable from inside
    # mailer conf templates via binding
    vcbdb = options[:vcbdb][0]
    hostname = `hostname`.chomp
    now = Time.now
    $mail.send({'vcb-ex.log' => File.read($log.temp.path)},
               binding)
  end
end
exit ($log.errors + $log.warns)
