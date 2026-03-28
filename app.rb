require 'sinatra/base'
require 'sinatra/json'
require 'json'

class App < Sinatra::Base
  configure do
    set :show_exceptions, false
    set :raise_errors, false
  end

  before do
    content_type :json
    if request.body.size > 0
      request.body.rewind
      body = request.body.read
      begin
        @request_body = JSON.parse(body) unless body.empty?
      rescue JSON::ParserError
        halt 400, { error: 'Invalid JSON' }.to_json
      end
    end
  end

  # Health check
  get '/health' do
    json status: 'ok', timestamp: Time.now.utc.iso8601
  end

  # Root
  get '/' do
    json message: 'Ruby API Server', version: '1.0.0'
  end

  # Example resource: items
  get '/items' do
    json items: ITEMS
  end

  get '/items/:id' do
    item = ITEMS.find { |i| i[:id] == params[:id].to_i }
    halt 404, { error: 'Item not found' }.to_json unless item
    json item
  end

  post '/items' do
    halt 400, { error: 'Missing body' }.to_json unless @request_body
    halt 422, { error: 'name is required' }.to_json unless @request_body['name']

    item = { id: ITEMS.size + 1, name: @request_body['name'] }
    ITEMS << item
    status 201
    json item
  end

  put '/items/:id' do
    item = ITEMS.find { |i| i[:id] == params[:id].to_i }
    halt 404, { error: 'Item not found' }.to_json unless item
    halt 400, { error: 'Missing body' }.to_json unless @request_body

    item[:name] = @request_body['name'] if @request_body['name']
    json item
  end

  delete '/items/:id' do
    item = ITEMS.find { |i| i[:id] == params[:id].to_i }
    halt 404, { error: 'Item not found' }.to_json unless item

    ITEMS.delete(item)
    status 204
  end

  # 404 handler
  not_found do
    json error: 'Route not found'
  end

  # Error handler
  error do
    json error: env['sinatra.error'].message
  end
end

ITEMS = [
  { id: 1, name: 'Item One' },
  { id: 2, name: 'Item Two' }
]
