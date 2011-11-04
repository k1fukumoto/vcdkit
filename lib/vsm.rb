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
require 'pp'

module VShieldManager

  class VSM < XMLElement
    def connect(host,user)
      @apiurl = "https://#{host}/api/2.0"
      @auth_token = {:Authorization => 'Basic YWRtaW46ZGVmYXVsdA=='}
      xml = self.get("#{@apiurl}/networks/edge/capability")
      doc = REXML::Document.new(xml)
      netid = doc.root.elements['//networkId'].text
      
      doc = REXML::Document.new(self.get("#{@apiurl}/networks/#{netid}/edge/dhcp/service"))
      REXML::Formatters::Pretty.new.write(doc.root,STDOUT)

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
  end
end

$VSM = [
        ['10.128.0.63','vcdadmin'],
        ['10.128.1.63','vcdadmin'],
        ['192.168.2.11','admin'],
       ]

def vsmopts(options,opt)
  opt.on('','--vsm HOST,USER',Array,'vShield Manager login parameters') do |o|
    if(o[0].size == 1)
      options[:vsm] = $VSM[o[0].to_i - 1]
    else
      options[:vsm] = o
    end
  end
end

