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
require 'rexml/document'
require 'erb'
require 'vclouddata'
require 'pp'

module VCloud

  VAPPSTATUS = {
    "4" => "Powered On",
    "8" => "Powered Off",
  }

  class Vm < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'

    def os
      @doc.elements["//ovf:OperatingSystemSection/ovf:Description/text()"]
    end
    def osType
      @doc.elements["//ovf:OperatingSystemSection/@vmw:osType"].value
    end

    def status
      VAPPSTATUS[@doc.elements["/Vm/@status"].value] || "Busy"
    end

    def thumbnail
      @vcd.get(@doc.elements["//Link[@rel='screen:thumbnail']/@href"].value).body
    end

    def moref
      @doc.elements["//VCloudExtension/vmext:VimObjectRef/vmext:MoRef/text()"]
    end
    
    def powerOff
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//Link[@rel='power:powerOff']"],
                   [], :post)
    end

    def editNetworkConnectionSection(ntwkcon)
      ncs = NetworkConnectionSection.new(ntwkcon)
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//NetworkConnectionSection/Link[@rel='edit']"],
                   [], :put,
                   ncs.xml(true),
                   {:content_type => NetworkConnectionSection::TYPE})
    end

    def editGuestCustomizationSection(node)
      gcs = GuestCustomizationSection.new(node)
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//GuestCustomizationSection/Link[@rel='edit']"],
                   [], :put,
                   gcs.xml(true),
                   {:content_type => GuestCustomizationSection::TYPE})
    end

    def editOperatingSystemSection(node)
      oss = OperatingSystemSection.new(node)
      task = Task.new
      task.connect(@vcd,
                   # Can't locate Link node if @rel='edit' is specified... 
                   @doc.elements["//ovf:OperatingSystemSection/Link"],
                   [], :put,
                   oss.xml(true),
                   {:content_type => OperatingSystemSection::TYPE})
    end

    def connectNetwork(nic,name,mode)
      ncon = @doc.elements["//NetworkConnection[NetworkConnectionIndex ='#{nic}']"]
      ncon.attributes['network'] = name
      ncon.elements["//IsConnected"].text = 'true'
      ncon.elements["//IpAddressAllocationMode"].text = mode
      cfg = ncon.elements["../"]

      task = Task.new
      task.connect(@vcd,
                   cfg.elements["//Link[@type='#{NetworkConnectionSection::TYPE}']"],
                   [], :put,
                   self.compose_xml(cfg),
                   :content_type => NetworkConnectionSection::TYPE)
    end

    def disconnectNetworks()
      self.editNetworkConnectionSection(nil)
    end

    def customize(args)
      cfg = @doc.elements["//GuestCustomizationSection"]
      GuestCustomizationSection.compose(cfg,args)

      task = Task.new
      task.connect(@vcd,
                   cfg.elements["//Link[@type='#{GuestCustomizationSection::TYPE}']"],
                   [], :put,
                   self.compose_xml(cfg),
                   :content_type => GuestCustomizationSection::TYPE)
    end

    def edit(src)
      task = Task.new
      task.connect(@vcd,
                   self.elements["//Link[@type='#{EditVmParams::TYPE}' and @rel='edit']"],
                   [], :put,
                   EditVmParams.new(src).xml,
                   {:content_type => EditVmParams::TYPE})
      
    end

    def initialize(parent,name)
      @parent = parent; @name = name
    end

    def path
      "#{@parent.path}/VM/#{@name}"
    end
  end

  class VmTemplate < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'
    def initialize(parent,name)
      @parent = parent; @name = name
    end

    def moref
      @doc.elements["//VCloudExtension/vmext:VimObjectRef/vmext:MoRef/text()"]
    end
    
    def path
      "#{@parent.path}/VMTEMPLATE/#{@name}"
    end
  end

  class VAppTemplate < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vAppTemplate+xml'

    def initialize(org,vdc,name)
      @org = org; @vdc = vdc; @name = name
    end
      
    def path
      "/ORG/#{@org}/VDC/#{@vdc}/VAPPTEMPLATE/#{@name}"
    end

    def vm(name)
      vm = VmTemplate.new(self,name)
      if(@vcd)
        vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
      elsif(@dir)
        vm.load(@dir)
      end
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = VmTemplate.new(self,n.attributes['name'].to_s)
        if(@vcd)
          vm.connect(@vcd,n)
        elsif(@dir)
          vm.load(@dir)
        end
        yield vm
      }
    end

    def save(dir)
      super
      self.each_vm {|vm| vm.save(dir)}
    end

    def saveparam(dir)
      super
      self.each_vm {|vm| vm.saveparam(dir)}
    end

    def delete
      @vcd.delete(@doc.elements["//Link[@rel='remove']/@href"].value)
    end
  end

  class ControlAccessParams < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.controlAccess+xml'

    def initialize(org,vdc,name)
      @org = org; @vdc = vdc; @name = name
    end
      
    def path
      "/ORG/#{@org}/VDC/#{@vdc}/VAPP/#{@name}"
    end

    def each_access_setting
      @doc.elements.each("//AccessSetting"){|n| 
        as = AccessSetting.new
        as.connect(@vcd,n,[:type])
        yield as
      }
    end
  end

  class VApp < VAppTemplate
    TYPE = 'application/vnd.vmware.vcloud.vApp+xml'

    def initialize(org,vdc,name)
      @org = org; @vdc = vdc; @name = name
    end
      
    def path
      "/ORG/#{@org}/VDC/#{@vdc}/VAPP/#{@name}"
    end

    def vm(name)
      vm = Vm.new(self,name)
      if(@vcd)
        vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
      elsif(@dir)
        vm.load(@dir)
      end
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = Vm.new(self,n.attributes['name'].to_s)
        if(@vcd)
          vm.connect(@vcd,n)
        elsif(@dir)
          vm.load(@dir)
        end
        yield vm
      }
    end

    def save(dir)
      super
      self.cap.save(dir)
    end

    def status
      VAPPSTATUS[@doc.elements["/VApp/@status"].value] || "Busy"
    end

    def deploy()
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//Link[@type='#{DeployVAppParams::TYPE}']"],
                   [], :post,
                   DeployVAppParams.new().xml,
                   {:content_type => DeployVAppParams::TYPE})
    end

    def editNetworkConfigSection(e)
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//NetworkConfigSection/Link[@rel='edit']"],
                   [], :put,
                   NetworkConfigSection.new(e).xml(true),
                   {:content_type => NetworkConfigSection::TYPE})
    end

    def editLeaseSettingsSection(e)
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//LeaseSettingsSection/Link[@rel='edit']"],
                   [], :put,
                   LeaseSettingsSection.new(e).xml(true),
                   {:content_type => LeaseSettingsSection::TYPE})
    end

    def editStartupSection(e)
      task = Task.new
      task.connect(@vcd,
                   # Adding @rel='edit' breaks the xpath search. Why??
                   @doc.elements["//ovf:StartupSection/Link"],
                   [], :put,
                   self.compose_xml(e,true),
                   {:content_type => StartupSection::TYPE})
    end

    def editControlAccessParams(e)
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["/VApp/Link[@rel='controlAccess']"],
                   [], :post,
                   self.compose_xml(e,true),
                   {:content_type => ControlAccessParams::TYPE})
    end

    def restore(src)
      # Disconnect VMs from networks to avoid 'unabled to delete networks' error
      self.each_vm {|vm| @vcd.wait(vm.disconnectNetworks())}

      # Restore control access settings
      @vcd.wait(self.editControlAccessParams(src.cap.doc.root))

      # StartupSection needs to be edited seperatelly from recompose.
      @vcd.wait(self.editStartupSection(src['//ovf:StartupSection']))

      # Name and Description needs to be changed from "edit" link of vApp.
      @vcd.wait(self.edit(src))

      # Use recompose API for the rest of settings.
      @vcd.wait(self.recomposeVApp(src))

      self.each_vm do |vm|
        srcvm = src.vm(vm.name)
        @vcd.wait(vm.edit(srcvm))
        @vcd.wait(vm.editNetworkConnectionSection(srcvm))
        @vcd.wait(vm.editGuestCustomizationSection(srcvm))
        @vcd.wait(vm.editOperatingSystemSection(srcvm))
      end
    end

    def recomposeVApp(src)
      task = Task.new
      task.connect(@vcd,
                   self.elements["//Link[@type='#{RecomposeVAppParams::TYPE}' and @rel='recompose']"],
                   [], :post,
                   RecomposeVAppParams.new(src).xml,
                   {:content_type => RecomposeVAppParams::TYPE})
      
    end

    def edit(src)
      task = Task.new
      task.connect(@vcd,
                   self.elements["//Link[@type='#{EditVAppParams::TYPE}' and @rel='edit']"],
                   [], :put,
                   EditVAppParams.new(src).xml,
                   {:content_type => EditVAppParams::TYPE})
      
    end

    def cap()
      unless(@cap)
        @cap = ControlAccessParams.new(@org,@vdc,@name)
        if(@vcd)
          n = REXML::XPath.first(@doc, "/VApp/Link[@type='#{ControlAccessParams::TYPE}' and @rel='down']")
          @cap.connect(@vcd,n)
        elsif(@dir)
          @cap.load(@dir)
        end
      end
      @cap
    end

    def powerOn
      task = Task.new
      if(@doc.elements["/VApp/@status"].value != "4")
        task.connect(@vcd,
                     @doc.elements["/VApp/Link[@rel='power:powerOn']"],
                     [], :post)
      end
      task
    end

    def powerOff
      task = Task.new
      if(@doc.elements["/VApp/@status"].value != "8")
        task.connect(@vcd,
                     @doc.elements["/VApp/Link[@rel='power:powerOff']"],
                     [], :post)
      end
      task
    end
    
    def undeploy
      task = Task.new
      if(@doc.elements["VApp/@deployed"].value == "true")
        task.connect(@vcd,
                     @doc.elements["//Link[@type='#{UndeployVAppParams::TYPE}']"],
                     [], :post,
                     UndeployVAppParams.new().xml,
                     {:content_type => UndeployVAppParams::TYPE})
      end
      task
    end
  end
end
