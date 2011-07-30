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
  class InvalidNameException < Exception
  end

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

    def vapptemplate(name)
      vat = VAppTemplate.new(@org,@name,name)
      vat.connect(@vcd,@doc.elements["//ResourceEntity[@type='#{VAppTemplate::TYPE}' and @name='#{name}']"])
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
      # self.savealt(dir) - TEST ONLY
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

  class Media < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.media+xml'
  end

  class CatalogItem < XMLElement
    TYPE = 'application/vnd.vmware.vcloud.catalogItem+xml'

    def initialize(org,cat,name)
      @org = org; @cat = cat; @name = name
    end
      
    def path
      "/ORG/#{@org}/CATALOG/#{@cat}/CATALOGITEM/#{@name}"
    end

    def type
      @doc.elements['/CatalogItem/Entity/@type'].value
    end

    def id
      self.entity_href =~ /media\/(\d+)$/
      sprintf('%010d',$1)
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
      # self.savealt(dir) - TEST ONLY
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
      n = @doc.elements["//Vdcs/Vdc[ @name='#{name}']"]
      if(n.nil?)
        $log.error("Cannot find vdc '#{name}': Available vdcs '#{self.vdcs.join(',')}'")
        raise InvalidNameException.new
      else
        vdc.connect(@vcd,n)
      end
    end

    def vdcs 
      @doc.elements.collect("//Vdcs/Vdc") {|n| n.attributes['name']}
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
      name.downcase!
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

    def add_user(name,role)
      task = Task.new
      task.connect(@vcd,
                   self.elements["//Link[@type='#{User::TYPE}' and @rel='add']"],
                   [], :post,
                   User.compose(name,role),
                   {:content_type => User::TYPE})
      
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
      # self.savealt(dir) -- TEST ONLY
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
    TYPE='application/vnd.vmware.admin.user+xml'
    XML=<<EOS
<User name="<%= name %>" 
  xmlns="http://www.vmware.com/vcloud/v1">
<FullName><%= name %></FullName>
<EmailAddress><%= name %>@vmware.com</EmailAddress>
<IsEnabled>true</IsEnabled>
<Role type="application/vnd.vmware.admin.role+xml"
  href="<%= role.href %>" name="<%= role.name %>"/>
<Password>password</Password>
</User>
EOS
    def initialize(org,name)
      @org = org; @name = name
    end
      
    def User.compose(name,role)
      ERB.new(XML).result(binding)
    end

    def path
      "/ORG/#{@org}/USER/#{@name}"
    end

    def disable
      self.elements['/User/IsEnabled'].text = 'false'
      @vcd.put(self.href,compose_xml(@doc.root,true),{:content_type => TYPE})
    end

    def delete
      @vcd.delete(self.href)
    end
  end

  class Role < XMLElement
    TYPE='application/vnd.vmware.admin.role+xml'

    def initialize(name)
      @name = name
    end
      
    def path
      "/ROLE/#{@name}"
    end
  end

  class VCD < XMLElement
    def path
      ""
    end

    def connect(host,org,user)
      pass = VCloud::SecurePass.new().decrypt(File.new('.vcd','r').read)
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
      self.each_role {|role| role.save(dir)}
    end

    def saveparam(dir)
      self.each_org {|org| org.saveparam(dir)}
    end

    ROLEPATH ='//RoleReferences/RoleReference'

    def role(name)
      role = Role.new(name)
      if(@auth_token)
        role.connect(self,@doc.elements["#{ROLEPATH}[@name='#{name}']"])
      elsif(@dir)
        role.load(@dir)
      end
    end

    def each_role
      @doc.elements.each(ROLEPATH) { |n| 
        role = Role.new(n.attributes['name'].to_s)
        if(@auth_token)
          role.connect(self,n)
        elsif(@dir)
          role.load(@dir)
        end
        yield role
      }
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

$VCD1 = ['vcd.vcdc.whitecloud.jp','System','vcdadminl']
$VCD2 = ['tvcd.vcdc.whitecloud.jp','System','vcdadminl']

$VSP1 = ['10.128.0.57','vcdadmin']
$VSP2 = ['10.128.1.57','vcdadmin']

