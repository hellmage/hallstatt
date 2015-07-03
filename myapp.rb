require "rubygems"
require "sinatra/base"
require 'rest-client'
require 'json'
require 'logger'
require 'byebug'

require './models'

CLIENT_ID = ENV['GH_BASIC_CLIENT_ID']
CLIENT_SECRET = ENV['GH_BASIC_SECRET_ID']
logger = Logger.new 'myapp.log'
logger.level = Logger::DEBUG

class MyApp < Sinatra::Base

  use Rack::Session::Cookie, {
    :secret => ENV['GH_COOKIE_SECRET'],
    :key => 'rack.session',
    :path => '/'
  }

  get '/' do
    user_session = session[:user_session]
    logger.info 'user_session: #{user_session}'
    user = User.first(:session_id => user_session)

    if !user  # unauthorized guest visit
      erb :index, :locals => {
        :scopes => ['user', 'repo'].join(','),
        :client_id => CLIENT_ID
      }
    else  # authorized user
      # get the list of repositories
      result = RestClient.get 'https://api.github.com/user/repos'
      repositories = JSON.parse(result)
      erb :index, :locals => {
        :user => user,
        :repositories => repositories,
      }
    end
  end

  get '/oauth/callback' do
    # get temporary GitHub code...
    session_code = request.env['rack.request.query_hash']['code']

    # ... and POST it back to GitHub
    logger.info 'making request to get access_token with #{session_code}'
    result = RestClient.post(
      'https://api.github.com/login/oauth/access_token',
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
    logger.info 'making request to get user with #{access_token}'
    result = RestClient.get(
      'https://api.github.com/user',
      {
        :params => {:access_token => access_token},
        :accept => :json
      }
    )
    user_login = JSON.parse(result)['login']
    user = User.first(:login => user_login)
    if !user
      logger.info 'Found user: #{login}'
      user = User.create(:login => user_login, :session_id => user_login)
      UserAccessToken.create({
        :access_token => access_token,
        :from => 'github',
        :user => user
      })
    end
    session[:user_session] = user.session_id
    redirect to('/')
  end

  get '/logout' do
    session.clear
  end

end
