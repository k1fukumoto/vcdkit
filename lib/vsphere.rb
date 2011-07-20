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
require 'rubygems'
require 'rbvmomi'
require 'erb'

#
# VSphere
#
module VSphere

  class Vm 
    attr_reader :name,:esx,:datastore

    def load(node)
      @name = node.attributes['name']
      @esx = node.elements["../@name"].value
   
      ds = node.elements["Datastore/@name"]
      @datastore = ""
      @datastore = ds.value unless ds.nil?
    end
  end

  class VCenter
    def connect(host,user,pass)
      @name = host

      @vim = RbVmomi::VIM.
        connect({ :host => host, 
                  :user => user, 
                  :password => pass, 
                  :insecure => true,
                })
      @root = @vim.serviceInstance.content.rootFolder
    end

    def vm(moref)
      @index_vm[moref.to_s]
    end

    def load(dir)
      @dir = dir
      @doc = REXML::Document.
        new(File.new("#{dir}/#{self.class.name.sub(/VSphere::/,'')}.xml"))

      @index_vm = @doc.elements.inject("//HostSystem/VirtualMachine",{}) {|h,e|
        vm = Vm.new
        vm.load(e)
        h.update(e.attributes['moref'] => vm)
        h
      }
    end

    def save(dir)
      xml = ERB.new(File.new('template/vsp_xml.erb').read,0,'>').result(binding)
      FileUtils.mkdir_p(dir) unless File.exists? dir
      open("#{dir}/#{self.class.name.sub(/VSphere::/,'')}.xml",'w') {|f| f.puts xml}
    end
  end
end




