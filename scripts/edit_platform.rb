### 
# A Kludge to quickly edit a platform section given id and a file to read from
#
# Id of "Academic Affairs" = 5, ID of "University-wide Initiatives" = 6
#
###

DataMapper::setup(:default,"sqlite3://#{Dir.pwd}/../goparty.db")

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

file = File.open(ARGV[0])
contents = file.read

s = Section.get 6
s[:text] = contents
s.save

