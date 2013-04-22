require 'sinatra'
require 'data_mapper'
require 'mandrill'
require 'json'
require 'pony'
require 'ri_cal'
#require 'google_drive'
#require "dm-migrations"
#require 'digest/sha1'
#require 'rack-flash3'
#require 'sinatra-authentication'

DataMapper::setup(:default,"sqlite3://#{Dir.pwd}/goparty.db")

ENV['MANDRILL_APIKEY'] = "-2_pDSbUJL75U2hc5_0ilg"
mandrill = Mandrill::API.new

set :username,'goparty2013'
set :password, 'Pl$D0ntH4x!'
set :token, 'u<Pb6;3XEk@XRF(JMtK'
set :FACEBOOK_URL, ""

#AUTHENTICATION!!!
helpers do

  def admin?
    request.cookies[settings.username] == settings.token
  end

  def protected!
    halt [ 401, 'Not Authorized' ] unless admin?
  end

end

class String
  def to_bool 
    self == "true"
  end
end

class Person
  include DataMapper::Resource
  
  property :id, Serial
  property :first_name, String
  property :last_name, String
  property :res_hall, String
  property :college, String
  property :email, String
  property :phone, String

end

class Candidate
  include DataMapper::Resource
  property :id, Serial
  property :name, String, :required => true
  property :description, Text
  property :title, String 
  property :video, String
  property :img, String
  property :type, String
end

class Platform
  include DataMapper::Resource

  property :id, Serial
  property :title, String
  property :text, Text
  property :slug, String

  has n, :sections
end


class Section
  include DataMapper::Resource

  property :id, Serial
  property :title, String, :required => true
  property :text, Text
  property :slug, String


belongs_to :platform
end

class Email 
  include DataMapper::Resource 

  property :id, Serial
  property :title, String, :required => true
  property :text, Text
  property :sent, Boolean, :default => false
  property :sent_time, DateTime
  property :recipients, Text
  
end

DataMapper.auto_upgrade!

helpers do
  def printActiveIfMatches s
    if s.index request.path_info
      'class="active"'
    end
  end
end

#get '/' do
#  erb :home do 
#    erb :init
#  end
#end

get '/' do
  erb :home do
    erb :init_week2
  end
end

get '/login' do
  erb :login
end

post '/login' do
  if params['username']==settings.username&&params['password']==settings.password
    response.set_cookie(settings.username,settings.token) 
    redirect '/'
  else
    "Username or Password incorrect"
  end
end

get '/logout' do
  response.set_cookie(settings.username, false) 
  redirect '/' 
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
  c[:type]        = params[:type]

  if ( params[:img] && (tmpfile = params[:img][:tempfile]) &&
       (name = params[:img][:filename]) )


    File.open(File.join(Dir.pwd,"public/uploads",name),"wb") {
      |f| f.write(tmpfile.read)
    }

    c[:img] = "/uploads/" + name

  else
    c[:img] = "http://placehold.it/210x315&text=no+picture"
  end
  c.save
  redirect '/candidates'
end

get '/candidates/create' do
  protected!
  erb :candidates_form
end

get '/platform' do
  @platforms = Platform.all
  erb :platform
end

get '/platform/create' do
  protected!
  erb :platform_form
end

post '/platform' do
  p = Platform.new
  p[:title] = params[:page][:title]
  p[:slug] = params[:page][:title].gsub(/\W/,"").gsub(/\s+/,"-")
  p[:text] = params[:page][:text]
  if( params[:subsection] && params[:subsection].length > 0 )
    params[:subsection].each_with_index do |sub,i|
      s = Section.new
      s[:title] = sub[1][:title]
      s[:slug] = sub[1][:title].gsub(/\s+/,"-")
      s[:text] = sub[1][:text]
      s.save 
      p.sections << s
    end
  end
  p.save
  redirect '/platform' 
end

get '/candidates/admin' do
  protected!
  
  @candidates = Candidate.all
  erb :candidates_admin

end

delete '/candidates/:id' do
  protected!
  Candidate.get(params[:id].to_i).destroy
end

post '/candidates/:id' do
  protected!
  c = Candidate.get(params[:id].to_i)
  c[:name]        = params[:name]
  c[:description] = params[:description]
  c[:title]       = params[:title]
  c[:video]       = params[:video]

  c.save
  redirect '/candidates/admin'
end

get '/candidates/:id/edit' do
  protected!
  @c = Candidate.get(params[:id].to_i)
  
  erb :candidate_edit
end


get '/platform/admin' do
  protected!
  
  @platforms = Platform.all
  erb :platform_admin

end

delete '/platform/:id' do
  protected!
  Platform.get(params[:id].to_i).destroy
end

get '/email/create' do
  protected!
  erb :email_form
end

get '/email' do
  protected!
  @sent_emails = Email.all( :sent => true )
  @unsent_emails = Email.all( :sent => false, :order=> :sent_time.asc)
  erb :email
end

post '/email' do

  e = Email.new
  e[:title] = params[:subject]
  e[:text] = params[:body]
  e[:sent] = false
  puts params[:recipients]
  e[:recipients] = params[:recipients].split(/[\s,]+/).map{ |name|
    {
      :email => name
    }
  }.to_json
  
  e.save

  redirect '/email'

end

post '/email/:id' do
  protected!
  e = Email.get( params[:id].to_i )
  e[:sent] = params[:send].to_bool
  e[:sent_time] = Time.now
  e.save

  #GOOGLE API STUFF
  #recipients = [ 
  #  {
  #    :email => "bobby.azarbayejani@gmail.com",
  #    :name => "Bobby Azarbayejani" 
  #  },
  #  { 
  #    :email => "aashish.gadani@gmail.com",
  #    :name => "Aashish Gadani"
  #  }
  #]
  recipients = JSON.parse(e[:recipients])


  ## MANDRILL API SEND
  mandrill.messages().send({
    :html => e[:text],
    :subject => e[:title],
    :from_email => "info@gopartyumd.com",
    :from_name => "Go Party",
    :to => recipients,
    :track_opens => false,
    :track_clicks => false,
    :auto_text => true,
    :auto_html => true,
    :inline_css => true
  })

  redirect '/email'

end

#survey has cols in this order:
# [ timestamp , first , last , college , reshall , email , phone ]
post '/survey' do

  p = Person.new
  p[:first_name] = params[:first]
  p[:last_name] = params[:last]
  p[:email] = params[:email]
  p.save

  redirect "/completesurvey?person_id=#{p[:id]}"

end

get '/completesurvey' do

  unless request.referrer && request.referrer.include?(request.host)
    redirect '/'
  end

  erb :home do 
    @person = Person.get(params["person_id"].to_i)
    erb :more_info
  end  

end

post '/completesurvey' do
  
  p = Person.get(params[:person_id].to_i)
  p[:res_hall] = params[:residence_hall]
  p[:phone] = params[:phone]
  p[:college] = params[:college]

  p.save

  redirect '/voting'

end

get '/voting' do
  erb :home do 
    erb :voting
  end
end

# Currently won't store anything, but may at some point, so post
post '/voting' do


  redirect '/thanks'
end

get '/thanks' do

  erb :home do
    erb :thanks
  end
end

get '/cal' do
  start_times = [" 8:00"," 12:00"," 15:00"]
  end_times = [" 9:00"," 13:00", " 16:00"]
  start = params[:date] + start_times[params[:time].to_i-1]
  endtime = params[:date] + end_times[params[:time].to_i-1] 
  
  a = RiCal.Calendar do
        event do
          summary "Vote for Go Party!"
          description "Vote for Go Party!"
          dtstart Date.strptime start, '%m/%d/%Y %H:%M' 
          dtend Date.strptime endtime, '%m/%d/%Y %H:%M'
          location "Your Desk"
        end
  end

  attachment "cal.ics"
  a.to_rfc2445_string

end

get '/sugg' do
  erb :sugg
end

post '/sugg' do
  Pony.mail :from => params[:from] || "gopartyumd@gmail.com",
            :to => "gopartyumd@gmail.com",
            :subject => params[:subject] || "Suggestion",
            :body => Rack::Utils.escape_html(params[:body])

  redirect '/'
end

