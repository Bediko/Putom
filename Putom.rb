require 'faraday'
require 'faraday_middleware'
require 'awesome_print'
require 'builder'
require 'open-uri'
$token=IO.readlines("token")
$putio_connection = Faraday.new('https://api.put.io/v2/') do |faraday|
  faraday.request :oauth2, $token[0], param_name: :oauth_token
  faraday.response :json, content_type: /\bjson$/
  faraday.response :raise_error
  faraday.adapter Faraday.default_adapter
end

def create_entries(files,feed)
  files.each do |file|
    if file["content_type"] == "application/x-directory"
      directory = $putio_connection.get do |req|
        req.url 'files/list'
        req.params['parent_id'] = file["id"]
      end
      create_entries directory.body["files"],feed
    else
			begin
        if file["content_type"] == "video/mp4"
          downurl = $putio_connection.get("files/#{file['id']}/download").headers["location"]
        else
          downurl = $putio_connection.get("files/#{file['id']}/mp4/download").headers["location"]
        end
        feed.entry do
        	feed.id "urn:put-io:files:#{file['id']}"
          feed.title file['name']
          feed.link	href: downurl,rel:"alternate"
          feed.author {feed.name "Putover"}
          feed.content file['name']
          feed.published "#{file['created_at']}Z"
      		feed.updated "#{file['created_at']}Z"
        end  

      rescue Faraday::Error::ResourceNotFound
      	next
			end
    end
  end
  return files,feed
end

def create_feed(buffer,files)
  atom = Builder::XmlMarkup.new(:target => buffer, :indent => 2)
  atom.instruct!
  atom.feed "xmlns" => "http://www.w3.org/2005/Atom" do
    atom.id "hurrdurr"																	#CHANGE ME IT HURTS!!!
    atom.updated Time.now.utc.iso8601(0)
    atom.title "Your Files", :type => "text"
    atom.link :rel => "self", :href => "/ruby_github.atom" #CHANGE ME IT HURTS!!!
    create_entries files,atom
  end
  return buffer
end
buffer=""
files = $putio_connection.get('files/list').body["files"]
buffer=create_feed buffer,files
File.open("atom", 'w') {|f| f.write(buffer) }