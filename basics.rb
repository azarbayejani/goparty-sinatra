require 'sinatra'
require 'data_mapper'
#require "dm-migrations"
#require 'digest/sha1'
#require 'rack-flash3'
#require 'sinatra-authentication'

DataMapper::setup(:default,"sqlite3://#{Dir.pwd}/goparty.db")

class Candidate
  include DataMapper::Resource
  property :id, Serial
  property :name, String, :required => true
  property :description, Text
  property :title, String 
  property :video, String, :required => true
  property :img, String
  property :type, String
end

class Platform
  include DataMapper::Resource

  property :id, Serial

  has n, :sections
end

class Section
  include DataMapper::Resource

  property :id, Serial
  property :title, String, :required => true
  property :text, Text, :required => true

  belongs_to :platform
end

DataMapper.auto_upgrade!

helpers do
  def printActiveIfMatches s
    if s == request.path_info
      'class="active"'
    end
  end
end

get '/' do
  "Hello, world!"
end

get '/candidates' do
  @exec = Candidate.all(:type => "executive", :order => :id.desc)
  @residential = Candidate.all( :type => "residential", :order => :title)
  @academic = Candidate.all( :type => "academic", :order => :title)
  @candidates = Candidate.all :order => :id.desc
  @title = "All Candidates"
  erb :candidates
end

post '/candidates' do
  c = Candidate.new
  c[:name]        = params[:name]
  c[:description] = params[:description]
  c[:title]       = params[:title]
  c[:video]       = params[:video]
  c[:img]         = params[:img]
  c[:type]        = params[:type]
  c.save
  redirect '/candidates'
end

get '/candidates/create' do
  erb :candidates_form
end

get '/platform/' do
  @platform = Platform.all, :id.desc
  erb :platform
end
