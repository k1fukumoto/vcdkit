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
require 'rubygems'
require 'highline/import'
require 'vcdkit'
require 'pp'

p = ask('Enter vCloud Director password:'){|q| q.echo = false}
open('.vcd','w'){|f| f.puts VCloud::SecurePass.new().encrypt(p)}

p = ask('Enter vCenter password:'){|q| q.echo = false}
open('.vc','w'){|f| f.puts VCloud::SecurePass.new().encrypt(p)}

p = ask('Enter vCenter Chargeback password:'){|q| q.echo = false}
open('.vb','w'){|f| f.puts VCloud::SecurePass.new().encrypt(p)}
