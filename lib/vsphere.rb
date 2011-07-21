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

  class DatastoreBrowser
    def initialize(ds)
      @datastore = ds
    end

    def search(path,spec)
      begin 
        task = nil
        if (spec)
puts "SPEC SEARCH #{path}"
          task = @datastore.browser.SearchDatastoreSubFolders_Task('datastorePath' => path,'searchSpec' => spec)
        else
          task = @datastore.browser.SearchDatastoreSubFolders_Task(:datastorePath => path)
        end
        task.wait_for_completion
        task.info.result.each {|r| yield r}
      rescue Exception => e
      end
    end

    def each_media()
spec = RbVmomi::VIM::HostDatastoreBrowserSearchSpec.new
spec.query = [
  RbVmomi::VIM::FileQuery.new,
]

      self.search("[#{@datastore.info.name}]",spec) do |org|
        org.file.each do |f|
          puts f.path
        end
      end
raise "STOP"

      self.search("[#{@datastore.info.name}] vCDC-02/media/",nil) do |org|
        next unless org =~ /\d+-org/
        self.search(org,nil) do |vdc|
          next unless vdc =~ /\d+-vdc/
          self.search("[#{@datastore.info.name}]", spec) do |media|
            yield media
          end
        end
      end
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



      @root.childEntity.grep(RbVmomi::VIM::Datacenter).each do |dc|
        dc.datastore.each do |ds|
          dsb = DatastoreBrowser.new(ds)
          dsb.each_media do |m|
            pp m
          end
        end
        raise "STOP"
      end
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




