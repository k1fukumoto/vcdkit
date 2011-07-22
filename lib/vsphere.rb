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
  class Media
    attr_reader :path,:vdc,:datastore
    def load(node)
      @path = node.elements["./@path"].value
      @vdc = node.elements["./VDC/@path"].value
      @datastore = node.elements["./Datastore/@path"].value
    end
  end

  class Vm 
    attr_reader :name,:esx,:datastore,:guestFullName,:guestFamily

    def load(node)
      @name = node.attributes['name']
      @esx = node.elements["../@name"].value
      
      @guestFullName = node.elements["./Guest/@name"].value
      @guestFamily = node.elements["./Guest/@family"].value


      ds = node.elements["./Datastore/@name"]
      @datastore = ""
      @datastore = ds.value unless ds.nil?
    end
  end

  class DatastoreBrowser
    def initialize(ds)
      @datastore = ds
    end

    def search(path)
      spec = RbVmomi::VIM::HostDatastoreBrowserSearchSpec.new
      spec.query = [RbVmomi::VIM::FileQuery.new]
      begin 
        task = @datastore.browser.SearchDatastoreSubFolders_Task('datastorePath' => path,'searchSpec' => spec)
        task.wait_for_completion
        task.info.result
      rescue Exception => e
        []
      end
    end

    def each_media()
      self.search("[#{@datastore.info.name}] vCDC-02/media/").each do |f|
        orgpath = f.folderPath
        next unless orgpath =~ /(\d+-org)/
        org = $1

        self.search(orgpath).each do |f|
          vdcpath = f.folderPath
          next unless vdcpath =~ /(\d+-vdc)/
          vdc = $1

          self.search(vdcpath).each do |f|
            f.file.each {|f| yield [@datastore.info.name,org,vdc,f.path]}
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
    end

    def vm(moref)
      @index_vm[moref.to_s]
    end

    def media(id)
      @index_media[id]
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
      @index_media = @doc.elements.inject("//MediaList/Media",{}) {|h,e|
        m = Media.new
        m.load(e)
        e.attributes['path'] =~ /(\d+)\-media\.iso/
        h.update($1 => m)
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




