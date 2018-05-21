## Copyright (c) 2015 SONATA-NFV, 2017 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## ALL RIGHTS RESERVED.
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
##
## Neither the name of the SONATA-NFV, 5GTANGO [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote
## products derived from this software without specific prior written
## permission.
##
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the SONATA
## partner consortium (www.sonata-nfv.eu).
##
## This work has been performed in the framework of the 5GTANGO project,
## funded by the European Commission under Grant number 761493 through
## the Horizon 2020 and 5G-PPP programmes. The authors would like to
## acknowledge the contributions of their colleagues of the 5GTANGO
## partner consortium (www.5gtango.eu).
# frozen_string_literal: true
# encoding: utf-8
require_relative '../spec_helper'

RSpec.describe FetchServicesService do
  let(:catalogue_url)  {FetchPackagesService::CATALOGUE_URL}
  
  it 'breaks unless CATALOGUE_URL ENV message is defined' do
    expect(described_class.const_defined?(:CATALOGUE_URL)).to be_truthy   
  end
  
  describe '.call' do    
    let(:uuid_1) {SecureRandom.uuid}
    let(:uuid_2) {SecureRandom.uuid}
    let(:service_1_metadata) {{uuid: uuid_1, nsd: {vendor: '5gtango', name: 'whatever', version: '0.0.1'}}}
    let(:service_2_metadata) {{uuid: uuid_2, nsd: {vendor: '5gtango', name: 'whatever', version: '0.0.2'}}}
    let(:services_metadata) {[service_1_metadata,service_2_metadata]}
    let(:default_page_size) {ENV.fetch('DEFAULT_PAGE_SIZE', '100')}
    let(:default_page_number) {ENV.fetch('DEFAULT_PAGE_NUMBER', '0')}
    let(:headers) {{'content-type' => 'application/json'}}
    
    it 'calls the Catalogue with default params' do      
      stub_request(:get, catalogue_url+'/network-services?page_number='+default_page_number+'&page_size='+default_page_size).
        to_return(status: 200, body: services_metadata.to_json, headers: headers)
      expect(described_class.call({})).to eq(services_metadata)
    end
    it 'calls the Catalogue with default page_size when only page_number is passed' do      
      stub_request(:get, catalogue_url+'/network-services?page_number=1&page_size='+default_page_size).
        to_return(status: 200, body: [].to_json, headers: headers)
      expect(described_class.call({page_number: 1})).to eq([])
    end
    it 'calls the Catalogue with default page_number when only page_size is passed' do      
      stub_request(:get, catalogue_url+'/network-services?page_number='+default_page_number+'&page_size=1').
        to_return(status: 200, body: [service_1_metadata].to_json, headers: headers)
      expect(described_class.call({page_size: 1})).to eq([service_1_metadata])
    end
    it 'calls the Catalogue with default page_number and page_size, returning existing services' do      
      stub_request(:get, catalogue_url+'/network-services?page_number='+default_page_number+'&page_size='+default_page_size).
        to_return(status: 200, body: services_metadata.to_json, headers: headers)
      expect(described_class.call({page_size: default_page_size, page_number: default_page_number})).to eq(services_metadata)
    end
    context 'calls the Catalogue with the passed UUID' do
      it 'return Ok (200) for existing UUIDs' do      
        stub_request(:get, catalogue_url+'/network-services/'+uuid_1).
          to_return(status: 200, body: service_1_metadata.to_json, headers: headers)
        expect(described_class.call({service_uuid: uuid_1})).to eq(service_1_metadata)
      end
      it 'return Not Found (404) for non-existing UUIDs' do      
        stub_request(:get, catalogue_url+'/network-services/'+uuid_1).
          to_return(status: 404, body: '', headers: headers)
        expect(described_class.call({service_uuid: uuid_1})).to be_falsy
      end
    end
  end
end