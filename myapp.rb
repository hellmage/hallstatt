require "rubygems"
require "sinatra/base"
require 'rest-client'
require 'json'
require 'logger'

require './models'

CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']
logger = Logger.new('myapp.log', 'view')

class MyApp < Sinatra::Base

  use Rack::Session::Pool, :cookie_only => false

  def authenticate?
    session_id = session[:session_id]
    @user = User.get(:session_id => session_id)
    if @user
      true
    else
      false
    end
  end

  get '/' do
    if !authenticate?
      erb :index, :locals => {
        :scopes => ['user', 'repo'].join(','),
        :client_id => CLIENT_ID
      }
    else
      erb :index, :locals => {
        :user => @user
      }
    end
  end

  get '/oauth/callback' do
    # get temporary GitHub code...
    session_code = request.env['rack.request.query_hash']['code']

    # ... and POST it back to GitHub
    logger.debug('making request to get access_token with #{session_code}')
    result = RestClient.post(
      'https://github.com/login/oauth/access_token',
      {
        :client_id => CLIENT_ID,
        :client_secret => CLIENT_SECRET,
        :code => session_code
      },
      :accept => :json
    )

    # extract the token and granted scopes
    access_token = JSON.parse(result)['access_token']

    # send request to github to get user information
    logger.debug('making request to get user with #{access_token}')
    result = RestClient.get(
      'http://api.github.com/user',
      {
        :params => {:access_token => access_token},
        :accept => :json
      }
    )
    email = JSON.parse(result)['email']
    user = User.first_or_create(:email => email, :session_id => email)
    token = UserAccessToken.create({
      :access_token => access_token,
      :from => 'github',
      :user => user
    })
  end

end
