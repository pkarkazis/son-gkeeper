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
# encoding: utf-8
require 'sinatra/namespace'
class GtkApi < Sinatra::Base

  register Sinatra::Namespace
  
  namespace '/api/v2/requests' do
    before do
      content_type :json
    end
    
    options '/?' do
      response.headers['Access-Control-Allow-Origin'] = '*'
      response.headers['Access-Control-Allow-Methods'] = 'POST,PUT'      
      response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With'
      halt 200
    end
  
    # POST a request
    post '/?' do
      began_at = Time.now.utc
      log_message = 'GtkApi::POST /api/v2/requests/'
      params = JSON.parse(request.body.read)
      logger.debug(log_message) {"entered with params=#{params}"}
      require_param(param: 'service_uuid', params: params, kpi_method: method(:count_service_instantiation_requests), error_message: 'Service UUID', log_message: log_message, began_at: began_at)
      require_param(param: 'egresses', params: params, kpi_method: method(:count_service_instantiation_requests), error_message: 'Egresses list', log_message: log_message, began_at: began_at)
      require_param(param: 'ingresses', params: params, kpi_method: method(:count_service_instantiation_requests), error_message: 'Ingresses list', log_message: log_message, began_at: began_at)
      
      token = get_token( request.env, began_at, method(:count_service_instantiation_requests), log_message)
      user_name = get_username_by_token( token, began_at, method(:count_service_instantiation_requests), log_message)
      
      validate_user_authorization(token: token, action: 'post service instantiation request', uuid: params['service_uuid'], path: '/services', method:'POST', kpi_method: method(:count_service_instantiation_requests), began_at: began_at, log_message: log_message)
      logger.debug(log_message) {"User authorized"}
      
      new_request = ServiceManagerService.create_service_instantiation_request(params)
      logger.debug(log_message) { "new_request =#{new_request}"}
      if new_request[:status] != 201
        count_service_instantiation_requests(labels: {result: "bad request", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 400, 'No request was created', log_message
      end
      count_service_instantiation_requests(labels: {result: "ok", uuid: new_request[:items][:service_uuid], elapsed_time: (Time.now.utc-began_at).to_s})
      halt 201, new_request[:items].to_json
    end

    # GET many requests
    get '/?' do
      began_at = Time.now.utc
      MESSAGE = 'GtkApi::GET /api/v2/requests/'
    
      @offset ||= params['offset'] ||= DEFAULT_OFFSET 
      @limit ||= params['limit'] ||= DEFAULT_LIMIT

      logger.info(MESSAGE) {'entered with '+query_string}
      token = get_token( request.env, began_at, method(:count_services_instantiation_requests_queries), MESSAGE)
      user_name = get_username_by_token( token, began_at, method(:count_services_instantiation_requests_queries), MESSAGE)

      validate_user_authorization(token: token, action: 'get requests data', uuid: '', path: '/requests', method:'GET', kpi_method: method(:count_function_metadata_queries), began_at: began_at, log_message: MESSAGE)
      logger.debug(MESSAGE) {"User authorized"}
      
      requests = ServiceManagerService.find_requests(params)
      logger.debug(MESSAGE) {"requests = #{requests}"}
      validate_collection_existence(collection: requests, name: 'requests', kpi_method: method(:count_services_instantiation_requests_queries), began_at: began_at, log_message: MESSAGE)
      
      links = build_pagination_headers(url: request_url, limit: @limit.to_i, offset: @offset.to_i, total: requests[:count])
      headers 'Link' => links, 'Record-Count' => requests[:count].to_s, 'Content-Type'=>'application/json'
      count_services_instantiation_requests_queries(labels: {result: "ok", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
      halt 200, requests[:items].to_json
    end
  
    # GET one specific request
    get '/:uuid/?' do
      began_at = Time.now.utc
      log_message = 'GtkApi::GET /api/v2/requests/:uuid/?'
      logger.debug(log_message) {"entered with #{params[:uuid]}"}
      validate_uuid(uuid: params[:uuid], kpi_method: method(:count_service_instantiation_requests_queries), began_at: began_at, log_message: log_message)
    
      token = get_token( request.env, began_at, method(:count_service_instantiation_requests_queries), log_message)
      user_name = get_username_by_token( token, began_at, method(:count_service_instantiation_requests_queries), log_message)

      validate_user_authorization(token: token, action: 'get request '+params[:uuid]+' data', uuid: params[:uuid], path: '/requests', method:'GET', kpi_method: method(:count_service_instantiation_requests_queries), began_at: began_at, log_message: log_message)
      logger.debug(log_message) {"User authorized"}
      
      request = ServiceManagerService.find_requests_by_uuid(params['uuid'])
      validate_element_existence(uuid: params[:uuid], element: request, name: 'Request', kpi_method: method(:count_service_instantiation_requests_queries), began_at: began_at, log_message: log_message)
      validate_ownership_and_licence(element: request[:items], user_name: user_name, kpi_method: method(:count_service_instantiation_requests_queries), began_at: began_at, log_message: log_message)
      
      count_service_instantiation_requests_queries(labels: {result: "ok", uuid: params[:uuid], elapsed_time: (Time.now.utc-began_at).to_s})
      logger.debug(log_message) {"leaving with #{request}"}
      headers 'Record-Count'=> '1'
      halt 200, request[:items].to_json
    end
    
    # PATCH /requests/:service_instance_uuid/stop
    patch '/:service_instance_uuid/stop/?' do
      began_at = Time.now.utc
      log_message = "GtkApi::PATCH /api/v2/requests/:service_instance_uuid/stop"
      logger.debug(log_message) {"entered with #{params[:service_instance_uuid]}"}

      validate_uuid(uuid: params[:service_instance_uuid], kpi_method: method(:count_service_instance_termination_requests), began_at: began_at, log_message: log_message)
      token = get_token( request.env, began_at, method(:count_service_instance_termination_requests), log_message)
      user_name = get_username_by_token( token, began_at, method(:count_service_instance_termination_requests), log_message)

      validate_user_authorization(token: token, action: 'patch request '+params[:service_instance_uuid]+' data', uuid: params[:service_instance_uuid], path: '/requests', method:'PATCH', kpi_method: method(:count_service_instance_termination_requests), began_at: began_at, log_message: log_message)
      logger.debug(log_message) {"User authorized"}
      
      termination_request = ServiceManagerService.create_service_termination_request(service_instance_uuid: params[:service_instance_uuid])
      json_error 400, 'Service instance termination request failled', log_message unless termination_request
        
      logger.debug(log_message) { "termination_request =#{termination_request}"}
      unless termination_request[:status] == 200
        count_service_instance_termination_requests(labels: {result: "bad request", uuid: '', elapsed_time: (Time.now.utc-began_at).to_s})
        json_error 400, 'Service instance termination request failled', log_message
      end
      count_service_instance_termination_requests(labels: {result: "ok", uuid: termination_request[:items][:service_uuid], elapsed_time: (Time.now.utc-began_at).to_s})
      halt 200, termination_request[:items].to_json
    end
  end

  namespace '/api/v2/admin/requests' do
    # GET module's logs
    get '/logs/?' do
      log_message = "GtkApi::GET /api/v2/admin/requests/logs"
      logger.debug(log_message) {"entered"}
      url = ServiceManagerService.class_variable_get(:@@url)+'/admin/logs'
      log = ServiceManagerService.get_log(url: url, log_message:log_message)
      logger.debug(log_message) {'leaving with log='+log}
      headers 'Content-Type' => 'text/plain; charset=utf8', 'Location' => '/api/v2/admin/requests/logs'
      halt 200, log
    end
  end
  
  private
  
  def count_service_instantiation_requests(labels:)
    name = __method__.to_s.split('_')[1..-1].join('_')
    desc = "how many service instantiations have been requested"
    ServiceManagerService.counter_kpi({name: name, docstring: desc, base_labels: labels.merge({method: 'POST', module: 'services'})})
  end
  
  def count_service_instance_termination_requests(labels:)
    name = __method__.to_s.split('_')[1..-1].join('_')
    desc = "how many service instances termination have been requested"
    ServiceManagerService.counter_kpi({name: name, docstring: desc, base_labels: labels.merge({method: 'PATCH', module: 'services'})})
  end

  def count_services_instantiation_requests_queries(labels:)
    name = __method__.to_s.split('_')[1..-1].join('_')
    desc = "how many service instantiation requests are there"
    ServiceManagerService.counter_kpi({name: name, docstring: desc, base_labels: labels.merge({method: 'GET', module: 'services'})})
  end
  
  def count_service_instantiation_requests_queries(labels:)
    name = __method__.to_s.split('_')[1..-1].join('_')
    desc = "how many specific service instantiation requests are there"
    ServiceManagerService.counter_kpi({name: name, docstring: desc, base_labels: labels.merge({method: 'GET', module: 'services'})})
  end
end
