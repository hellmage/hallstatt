require 'rubygems'
require 'data_mapper'
require 'dm-sqlite-adapter'
require 'bcrypt'

DataMapper.setup(:default, "sqlite://#{Dir.pwd}/db.sqlite")
DataMapper::Model.raise_on_save_failure = true

class User
  include DataMapper::Resource
  include BCrypt

  property :id, Serial, :key => true
  property :email, String, :length => 3..50, :unique => true, :required => true
  property :session_id, BCryptHash
  property :created_at, DateTime, :default => Time.now
  has n, :user_access_token

  def authenticate(submitted_session_id)
    if self.session_id == submitted_session_id
      true
    else
      false
    end
  end
end


class UserAccessToken
  include DataMapper::Resource

  belongs_to :user
  property :access_token, String, :length => 1..100, :key => true
  property :from, String, :length => 1..20, :key => true

end

DataMapper.finalize
DataMapper.auto_upgrade!
