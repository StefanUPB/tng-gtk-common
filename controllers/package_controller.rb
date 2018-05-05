## SONATA - Gatekeeper
##
## Copyright (c) 2015 SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
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
## Neither the name of the SONATA-NFV [, ANY ADDITIONAL AFFILIATION]
## nor the names of its contributors may be used to endorse or promote 
## products derived from this software without specific prior written 
## permission.
## 
## This work has been performed in the framework of the SONATA project,
## funded by the European Commission under Grant number 671517 through 
## the Horizon 2020 and 5G-PPP programmes. The authors would like to 
## acknowledge the contributions of their colleagues of the SONATA 
## partner consortium (www.sonata-nfv.eu).
# frozen_string_literal: true
# encoding: utf-8
require 'sinatra'
require 'json'
require 'logger'
require 'securerandom'
#require_relative '../services/upload_package_service'

class PackageController < ApplicationController

  INTERNAL_CALLBACK_URL = ENV.fetch('INTERNAL_CALLBACK_URL', 'http://tng-gtk-common:5000/on-change')
  ERROR_PACKAGE_NOT_FOUND="No package file with UUID '%s' was found"
  ERROR_PACKAGE_FILE_PARAMETER_MISSING={error: 'Package file name parameter is missing'}
  ERROR_PACKAGE_CONTENT_TYPE={error: 'Just accepting multipart package files for now'}
  ERROR_PACKAGE_ACCEPTATION={error: 'Problems accepting package for unpackaging and validation...'}
  ERROR_EVENT_CONTENT_TYPE={error: 'Just accepting callbacks in json'}
  ERROR_EVENT_PARAMETER_MISSING={error: 'Event received with no data'}
  OK_CALLBACK_PROCESSED = "Callback for process id %s processed"
  ERROR_PROCESS_UUID_NOT_VALID="Process UUID %s not valid"
  ERROR_NO_STATUS_FOUND="No status found for %s processing id"

  settings.logger.info(self.name) {"Started at #{settings.began_at}"}
  before { content_type :json}
  
  # Accept packages and pass them to the unpackager/validator component
  post '/?' do
    halt 400, {'content-type'=>'application/json'}, ERROR_PACKAGE_CONTENT_TYPE.to_json unless request.content_type =~ /^multipart\/form-data/
    
    begin
      ValidatePackageParametersService.call request.params
    rescue ArgumentError => e
      halt 400, {'content-type'=>'application/json'}, ERROR_PACKAGE_FILE_PARAMETER_MISSING.to_json
    end
    code, body = UploadPackageService.call( request.params, request.content_type, INTERNAL_CALLBACK_URL)
    halt 200, {'content-type'=>'application/json'}, body.to_json if code == 200
    halt code, {'content-type'=>'application/json'}, ERROR_PACKAGE_ACCEPTATION.to_json
  end
  
  # Callback for the tng-sdk-packager to notify the result of processing
  post '/on-change/?' do
    halt 400, {}, ERROR_EVENT_CONTENT_TYPE.to_json unless request.content_type =~ /application\/json/
    begin
      ValidateEventParametersService.call(request.body.read)
    rescue ArgumentError => e
      halt 400, {}, [e.message]
    end
    UploadPackageService.process_callback(event_data)
    halt 200, {}, OK_CALLBACK_PROCESSED % event_data
  end
  
  get '/status/:process_uuid/?' do
    halt 400, {}, {error: ERROR_PROCESS_UUID_NOT_VALID % params[:process_uuid]}.to_json unless uuid_valid?(params[:process_uuid])
    result = FetchPackagesService.status(params[:process_uuid])
    halt 404, {}, {error: ERROR_NO_STATUS_FOUND % params[:process_uuid]}.to_json if result.to_s.empty? 
    halt 200, {}, result.to_json
  end

  get '/?' do 
    captures=params.delete('captures') if params.key? 'captures'
    result = FetchPackagesService.metadata(params)
    halt 404, {}, {error: "No packages fiting the provided parameters ('#{params}') were found"}.to_json if result.to_s.empty? # covers nil
    halt 200, {}, result.to_json
  end
  
  get '/:package_uuid?' do 
    captures=params.delete('captures') if params.key? 'captures'
    result = FetchPackagesService.metadata(params)
    halt 404, {}, {error: "No package with UUID '#{params}' was found"}.to_json if result.to_s.empty? # covers nil
    halt 200, {}, result.to_json
  end
  
  get '/:package_uuid/package-file/?' do 
    captures=params.delete('captures') if params.key? 'captures'
    file_name = FetchPackagesService.package_file(params)
    halt 404, {}, {error: ERROR_PACKAGE_NOT_FOUND % params[:package_uuid]}.to_json if file_name.to_s.empty? # covers nil
    send_file '/tmp/'+file_name, type: 'application/zip', filename: file_name
  end

  private
  def uuid_valid?(uuid)
    return true if (uuid =~ /[a-f0-9]{8}-([a-f0-9]{4}-){3}[a-f0-9]{12}/) == 0
    false
  end
end
