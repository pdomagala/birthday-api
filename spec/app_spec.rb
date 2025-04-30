# spec/app_spec.rb
require 'rack/test'
require 'rspec'

ENV['RACK_ENV'] = 'test'
ENV['ENVIRONMENT'] = 'development'

require_relative '../app'

RSpec.describe 'Birthday API App' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  before(:each) do
    # Clean DB before each test
    DB.execute("DELETE FROM users;")
  end

  describe "GET /health" do
    it "returns UP status and environment" do
      get '/health'
      expect(last_response.status).to eq(200)
      data = JSON.parse(last_response.body)
      expect(data['status']).to eq('UP')
      expect(data['environment']).to eq('development')
    end
  end

  describe "PUT /hello/:username" do
    let(:valid_payload) { { dateOfBirth: '1996-04-20' }.to_json }

    it "saves user date of birth with valid input" do
      put '/hello/piotr', valid_payload, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(204)
    end

    it "returns 400 for invalid username" do
      put '/hello/michal321', valid_payload, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end

    it "returns 400 for invalid JSON" do
      put '/hello/john', 'not-json', { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end

    it "returns 400 for future date" do
      payload = { dateOfBirth: (Date.today + 1).to_s }.to_json
      put '/hello/bobby', payload, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end

    it "returns 400 when dateOfBirth is missing" do
      payload = {}.to_json
      put '/hello/john', payload, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(400)
    end
  end

  describe "GET /hello/:username" do
    it "returns birthday message when user exists" do
      DB.execute("INSERT INTO users (username, date_of_birth) VALUES (?, ?)", ['alice', '1990-01-01'])

      get '/hello/alice'
      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['message']).to include("Hello, alice!")
    end

    it "returns 404 when user does not exist" do
      get '/hello/unknownuser'
      expect(last_response.status).to eq(404)
    end

    it "returns 400 for invalid username" do
      get '/hello/1234'
      expect(last_response.status).to eq(400)
    end
  end
end
