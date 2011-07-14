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
  end

  class VAppTemplate < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.vAppTemplate+xml'

    def vm(name)
      vm = Vm.new
      if(@vcd)
        vm.connect(@vcd,@doc.elements["//Children/Vm[@name='#{name}']"])
      elsif(@dir)
        vm.load("#{@dir}/VM/#{name}")
      end
    end

    def each_vm
      @doc.elements.each("//Children/Vm"){|n| 
        vm = Vm.new
        if(@vcd)
          vm.connect(@vcd,n)
        elsif(@dir)
          vm.load("#{@dir}/VM/#{n.attributes['name']}")
        end
        yield vm
      }
    end

    def save(dir)
      super
      self.each_vm {|vm| vm.save("#{dir}/VM/#{vm.name}")}
    end

    def delete
      @vcd.delete(@doc.elements["//Link[@rel='remove']/@href"].value)
    end
  end

  class VApp < VAppTemplate
    TYPE = 'application/vnd.vmware.vcloud.vApp+xml'

    def connect(vcd,node)
      super(vcd,node)
      self
    end

    def saveparam(dir)
      super
      self.each_vm {|vm| vm.saveparam("#{dir}/VM/#{vm.name}")}
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

    def cap()
      unless(@cap)
        @cap = ControlAccessParams.new
        if(@vcd)
          n = REXML::XPath.first(@doc, "/VApp/Link[@type='#{ControlAccessParams::TYPE}' and @rel='down']")
          @cap.connect(@vcd,n)
        elsif(@dir)
          @cap.load(@dir)
        end
      end
      @cap
    end

    def save(dir)
      super
      self.cap.save(dir)
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

    def vapp(name)
      vapp = VApp.new
      vapp.connect(@vcd,@doc.elements["//ResourceEntity[@type='#{VApp::TYPE}' and @name='#{name}']"])
    end

    def each_vapp
      @doc.elements.each("//ResourceEntity[@type='#{VApp::TYPE}']"){|n|
        vapp = VApp.new
        if(@vcd)
          vapp.connect(@vcd,n)
        elsif(@dir)
          vapp.load("#{@dir}/VAPP/#{n.attributes['name']}")
        end
        yield vapp
      }
    end

    def each_vapptemplate
      @doc.elements.each("//ResourceEntity[@type='#{VAppTemplate::TYPE}']"){|n|
        vat = VAppTemplate.new
        if(@vcd)
          vat.connect(@vcd,n)
        elsif(@dir)
          vat.load("#{@dir}/VAPPTEMPLATE/#{n.attributes['name']}")
        end
        yield vat
      }
    end

    def save(dir)
      super
      self.each_vapp {|vapp| vapp.save("#{dir}/VAPP/#{vapp.name}")}
      self.each_vapptemplate {|vat| vat.save("#{dir}/VAPPTEMPLATE/#{vat.name}")}
    end

    def saveparam(dir)
      self.each_vapptemplate {|vat| vat.saveparam("#{dir}/VAPPTEMPLATE/#{vat.name}")}
      self.each_vapp {|vapp| vapp.saveparam("#{dir}/VAPP/#{vapp.name}")}
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

    def entity_href
      @doc.elements["/CatalogItem/Entity/@href"].value
    end
  end

  class Catalog < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalog+xml'

    def catalogitem(name)
      ci = CatalogItem.new
      ci.connect(@vcd,@doc.elements["//CatalogItem[@name='#{name}']"])
    end

    def each_catalogitem
      @doc.elements.each("//CatalogItem") do |n|
        ci = CatalogItem.new
        if(@vcd)
          ci.connect(@vcd,n)
        elsif(@dir)
          ci.load("#{@dir}/CATALOGITEM/#{n.attributes['name']}")
        end
        yield ci
      end
    end

    def save(dir)
      super
      self.each_catalogitem {|ci| ci.save("#{dir}/CATALOGITEM/#{ci.name}")}
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

    def vdc(name) 
      vdc = Vdc.new
      vdc.connect(@vcd,@doc.elements["//Vdcs/Vdc[ @name='#{name}']"])
    end

    def each_vdc
      @doc.elements.each("//Vdcs/Vdc") {|n| 
        vdc = Vdc.new
        if(@vcd)
          vdc.connect(@vcd,n)
        elsif(@dir)
          vdc.load("#{@dir}/VDC/#{n.attributes['name']}")
        end
        yield vdc
      }
    end

    USERPATH ='//Users/UserReference'

    def user(name)
      user = User.new
      if(@vcd)
        user.connect(@vcd,@doc.elements["#{USERPATH}[@name='#{name}']"])
      elsif(@dir)
        user.load("#{@dir}/USER/#{name}")
      end
    end

    def each_user
      @doc.elements.each(USERPATH) { |n| 
        user = User.new
        if(@vcd)
          user.connect(@vcd,n)
        elsif(@dir)
          user.load("#{@dir}/USER/#{n.attributes['name']}")
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
      cat = Catalog.new
      cat.connect(@vcd,@doc.elements["#{CATPATH}[@name='#{name}']"])
    end

    def each_catalog
      @doc.elements.each(CATPATH) {|n| 
        cat = Catalog.new
        if(@vcd)
          cat.connect(@vcd,n)
        elsif(@dir)
          cat.load("#{@dir}/CATALOG/#{n.attributes['name']}")
        end
        yield cat
      }
    end

    def save(dir)
      super
      self.each_vdc {|vdc| vdc.save("#{dir}/VDC/#{vdc.name}")}
      self.each_catalog {|cat| cat.save("#{dir}/CATALOG/#{cat.name}")}
      self.each_user {|user| user.save("#{dir}/USER/#{user.name}")}
    end

    def saveparam(dir)
      self.each_vdc {|vdc| vdc.saveparam("#{dir}/VDC/#{vdc.name}")}
      self.each_catalog {|cat| cat.saveparam("#{dir}/CATALOG/#{cat.name}")}
    end
  end

  class User < XMLElement
  end

  class VCD < XMLElement
    attr_reader :logger


    def connect(host,org,user,pass)
      @apiurl = "https://#{host}/api/v1.0"
      resp = RestClient::Resource.new("#{@apiurl}/login",
                                      :user => "#{user}@#{org}",
                                      :password => pass).post(nil)
      @auth_token = {:x_vcloud_authorization => resp.headers[:x_vcloud_authorization]}

      @xml = self.get("#{@apiurl}/admin")
      @doc = REXML::Document.new(@xml)
    end

    def load(dir,*target)
      case target.size
      when 0
        super
        @auth_token = nil
      when 3
        org = target[0]
        vdc = target[1]
        vapp = target[2]
        VApp.new.load("#{dir}/ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}")
      end
    end

    def save(dir,*target)
      case target.size
      when 0
        super
        self.each_org {|org| org.save("#{dir}/ORG/#{org.name}")}
      when 3
        org = target[0]
        vdc = target[1]
        vapp = target[2]
        self.org(org).vdc(vdc).vapp(vapp).save("#{dir}/ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}")
      end
    end

    def saveparam(dir,*target)
      case target.size
      when 0
        self.each_org {|org| org.saveparam("#{dir}/ORG/#{org.name}")}
      when 3
        org = target[0]
        vdc = target[1]
        vapp = target[2]
        self.org(org).vdc(vdc).vapp(vapp).saveparam("#{dir}/ORG/#{org}/VDC/#{vdc}/VAPP/#{vapp}")
      end
    end

    ORGPATH='//OrganizationReferences/OrganizationReference'

    def org(name)
      org = Org.new
      org.connect(self,@doc.elements["#{ORGPATH}[@name='#{name}']"])
    end

    def each_org
      @doc.elements.each(ORGPATH) { |n| 
        org = Org.new
        if(@auth_token)
          org.connect(self,n)
        elsif(@dir)
          org.load("#{@dir}/ORG/#{n.attributes['name']}")
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
          $log.info("#{response.code}>> #{response}")
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
          $log.info("#{response.code}>> #{response}")
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
          $log.info("#{response.code}<< #{payload}")
          $log.info("#{response.code}>> #{response}")
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
          $log.info("#{response.code}<< #{payload}")
          $log.info("#{response.code}>> #{response}")
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
