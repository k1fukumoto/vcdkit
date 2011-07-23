######################################################################################
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
require 'logger'
require 'vclouddata.rb'
require 'securepass.rb'
require 'vcloud.rb'
require 'vapp.rb'
require 'vsphere.rb'
require 'vcb.rb'

$VCDKIT=ENV['VCDKIT']
if $VCDKIT.nil?
  puts "Please set VCDKIT environment variable to installataion directory." 
  exit 1
end
Dir.chdir($VCDKIT)

