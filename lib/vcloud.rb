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
require 'rest_client'
require 'rexml/document'
require 'erb'
require 'vclouddata'
require 'pp'

module VCloud

  class Task < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.task+xml'
    def status
      if (@doc.nil? || @doc.elements["//Task/@status"].nil?)
        "success"
      else
        @doc.elements["//Task/@status"].value
      end
    end
  end

  VAPPSTATUS = {
    "4" => "Powered On",
    "8" => "Powered Off",
  }

  class Vm < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vm+xml'

    def os
      @doc.elements["//ovf:OperatingSystemSection/ovf:Description/text()"]
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

    def configureNetworkConnection(ntwkcon)
      ncs = NetworkConnectionSection.new(ntwkcon)
      task = Task.new
      task.connect(@vcd,
                   @doc.elements["//NetworkConnectionSection/Link[@rel='edit']"],
                   [], :put,
                   ncs.xml(true),
                   {:content_type => NetworkConnectionSection::TYPE})
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

    def initialize(org,vdc,vapp,name)
      @org = org; @vdc = vdc; @vapp = vapp; @name = name
    end

    def path
      "/ORG/#{@org}/VDC/#{@vdc}/VAPP/#{@vapp}/VM/#{@name}"
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
      vm = Vm.new(@org,@vdc,@name,name)
      if(@vcd)
        vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
      elsif(@dir)
        vm.load(@dir)
      end
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = Vm.new(@org,@vdc,@name,n.attributes['name'].to_s)
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

    def save(dir)
      super
      self.cap.save(dir)
    end

    def saveparam(dir)
      super
      self.each_vm {|vm| vm.saveparam(dir)}
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

    def restore(src)
      # For some reasons, StartupSection needs to be edited seperatelly from recompose.
      @vcd.wait(self.editStartupSection(src['//ovf:StartupSection']))

      # Name and Description needs to be changed from "edit" link of vApp.
      @vcd.wait(self.editVApp(src))

      # Use recompose function for the rest of settings.
      @vcd.wait(self.recomposeVApp(src))

      self.each_vm do |vm|
        @vcd.wait(vm.configureNetworkConnection(src.vm(vm.name)['//NetworkConnectionSection']))
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

    def editVApp(src)
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

  class Vdc < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vdc+xml'
    attr_reader :org

    def initialize(org,name)
      @org = org; @name = name
    end

    def path
      "/ORG/#{@org}/VDC/#{@name}"
    end

    def vapp(name)
      vapp = VApp.new(@org,@name,name)
      vapp.connect(@vcd,@doc.elements["//ResourceEntity[@type='#{VApp::TYPE}' and @name='#{name}']"])
    end

    def each_vapp
      @doc.elements.each("//ResourceEntity[@type='#{VApp::TYPE}']"){|n|
        vapp = VApp.new(@org,@name,n.attributes['name'].to_s)
        if(@vcd)
          vapp.connect(@vcd,n)
        elsif(@dir)
          vapp.load(@dir)
        end
        yield vapp
      }
    end

    def each_vapptemplate
      @doc.elements.each("//ResourceEntity[@type='#{VAppTemplate::TYPE}']"){|n|
        vat = VAppTemplate.new(@org,@name,n.attributes['name'].to_s)
        if(@vcd)
          vat.connect(@vcd,n)
        elsif(@dir)
          vat.load(@dir)
        end
        yield vat
      }
    end

    def save(dir)
      super
      self.each_vapp {|vapp| vapp.save(dir)}
      self.each_vapptemplate {|vat| vat.save(dir)}
    end

    def saveparam(dir)
      self.each_vapptemplate {|vat| vat.saveparam(dir)}
      self.each_vapp {|vapp| vapp.saveparam(dir)}
    end

    def cloneVApp(src,name,desc='')
      href = REXML::XPath.first(@doc, "//Link[@type='#{CloneVAppParams::TYPE}' and @rel='add']").attributes['href']
      xml = CloneVAppParams.new(src.href,name,desc).xml
      resp = @vcd.post(href, xml , :content_type => CloneVAppParams::TYPE)
    end

    def deployVApp(ci,name,ntwk,desc='')
      task = Task.new
      task.connect(@vcd,
                   self.alt.elements["//Link[@type='#{InstantiateVAppTemplateParams::TYPE}' and @rel='add']"],
                   [], :post,
                   InstantiateVAppTemplateParams.new(ci,name,ntwk,desc).xml,
                   {:content_type => InstantiateVAppTemplateParams::TYPE})
    end

    def composeVApp(src,name)
      task = Task.new
      task.connect(@vcd,
                   self.alt.elements["//Link[@type='#{ComposeVAppParams::TYPE}' and @rel='add']"],
                   [], :post,
                   ComposeVAppParams.new(src,name).xml,
                   {:content_type => ComposeVAppParams::TYPE})
      
    end

  end

  class CatalogItem < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalogItem+xml'

    def initialize(org,cat,name)
      @org = org; @cat = cat; @name = name
    end
      
    def path
      "/ORG/#{@org}/CATALOG/#{@cat}/CATALOGITEM/#{@name}"
    end

    def entity_href
      @doc.elements["/CatalogItem/Entity/@href"].value
    end
  end

  class Catalog < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalog+xml'

    def initialize(org,name)
      @org = org; @name = name
    end
      
    def path
      "/ORG/#{@org}/CATALOG/#{@name}"
    end

    def catalogitem(name)
      ci = CatalogItem.new(@org,@name,name)
      ci.connect(@vcd,@doc.elements["//CatalogItem[@name='#{name}']"])
    end

    def each_catalogitem
      @doc.elements.each("//CatalogItem") do |n|
        ci = CatalogItem.new(@org,@name,n.attributes['name'].to_s)
        if(@vcd)
          ci.connect(@vcd,n)
        elsif(@dir)
          ci.load(@dir)
        end
        yield ci
      end
    end

    def save(dir)
      super
      self.each_catalogitem {|ci| ci.save(dir)}
    end

    def saveparam(dir)
      # NOT IMPLEMENTED
    end
  end

  class OrgNetwork < XMLElement
    TYPE='application/vnd.vmware.vcloud.network+xml'
  end

  class Org < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.org+xml'

    def initialize(name)
      @name = name
    end

    def path
      "/ORG/#{@name}"
    end

    def vdc(name) 
      vdc = Vdc.new(@name,name)
      vdc.connect(@vcd,@doc.elements["//Vdcs/Vdc[ @name='#{name}']"])
    end

    def each_vdc
      @doc.elements.each("//Vdcs/Vdc") {|n| 
        vdc = Vdc.new(@name,n.attributes['name'].to_s)
        if(@vcd)
          vdc.connect(@vcd,n)
        elsif(@dir)
          vdc.load(@dir)
        end
        yield vdc
      }
    end

    USERPATH ='//Users/UserReference'

    def user(name)
      user = User.new(@name,name)
      if(@vcd)
        user.connect(@vcd,@doc.elements["#{USERPATH}[@name='#{name}']"])
      elsif(@dir)
        user.load("#{@dir}/USER/#{name}")
      end
    end

    def each_user
      @doc.elements.each(USERPATH) { |n| 
        user = User.new(@name,n.attributes['name'].to_s)
        if(@vcd)
          user.connect(@vcd,n)
        elsif(@dir)
          user.load(@dir)
        end
        yield user
      }
    end

    def network(name)
      ntwk = OrgNetwork.new
      ntwk.connect(@vcd,@doc.elements["//Networks/Network[@name='#{name}']"])
    end

    CATPATH = '//Catalogs/CatalogReference'

    def catalog(name)
      cat = Catalog.new(@name,name)
      cat.connect(@vcd,@doc.elements["#{CATPATH}[@name='#{name}']"])
    end

    def each_catalog
      @doc.elements.each(CATPATH) {|n| 
        cat = Catalog.new(@name,n.attributes['name'].to_s)
        if(@vcd)
          cat.connect(@vcd,n)
        elsif(@dir)
          cat.load(@dir)
        end
        yield cat
      }
    end

    def save(dir)
      super
      self.each_vdc {|vdc| vdc.save(dir)}
      self.each_catalog {|cat| cat.save(dir)}
      self.each_user {|user| user.save(dir)}
    end

    def saveparam(dir)
      self.each_vdc {|vdc| vdc.saveparam(dir)}
      self.each_catalog {|cat| cat.saveparam(dir)}
    end
  end

  class User < XMLElement
    def initialize(org,name)
      @org = org; @name = name
    end
      
    def path
      "/ORG/#{@org}/USER/#{@name}"
    end

  end

  class VCD < XMLElement
    attr_reader :logger

    def path
      ""
    end

    def connect(host,org,user,pass)
      @apiurl = "https://#{host}/api/v1.0"
      resp = RestClient::Resource.new("#{@apiurl}/login",
                                      :user => "#{user}@#{org}",
                                      :password => pass).post(nil)
      @auth_token = {:x_vcloud_authorization => resp.headers[:x_vcloud_authorization]}

      @xml = self.get("#{@apiurl}/admin")
      @doc = REXML::Document.new(@xml)
      self
    end

    def load(dir,*target)
      super
      @auth_token = nil
      self
    end

    def save(dir)
      super
      self.each_org {|org| org.save(dir)}
    end

    def saveparam(dir)
      self.each_org {|org| org.saveparam(dir)}
    end

    ORGPATH='//OrganizationReferences/OrganizationReference'

    def org(name)
      org = Org.new(name)
      org.connect(self,@doc.elements["#{ORGPATH}[@name='#{name}']"])
    end

    def each_org
      @doc.elements.each(ORGPATH) { |n| 
        org = Org.new(n.attributes['name'])
        if(@auth_token)
          org.connect(self,n)
        elsif(@dir)
          org.load(@dir)
        end
        yield org
      }
    end

    def get(url)
      $log.info("HTTP GET: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.get(url,@auth_token) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def delete(url)
      $log.info("HTTP DELETE: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.delete(url,@auth_token) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def post(url,payload=nil,hdrs={})
      $log.info("HTTP POST: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.post(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}<< #{payload}")
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def put(url,payload=nil,hdrs={})
      $log.info("HTTP PUT: #{url.sub(/#{@apiurl}/,'')}")
      RestClient.put(url,payload,hdrs.update(@auth_token)) { |response, request, result, &block|
        case response.code
        when 200..299
          response
        else
          $log.error("#{response.code}<< #{payload}")
          $log.error("#{response.code}>> #{response}")
          response.return!(request,result,&block)
        end
      }
    end

    def wait(task)
      while task.status == 'running'
        sleep(3)
        node = task.doc.root
        task = Task.new
        task.connect(self,node)
      end
    end  
  end
end
