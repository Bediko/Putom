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

def createEntries(list,atom)
	list.each do |item|
		if(item["content_type"]=="application/x-directory")
			directory = $putio_connection.get do |req|
				req.url 'files/list'
  			req.params['parent_id'] = item["id"]
			end
			createEntries directory.body["files"],atom
		else
			begin
				if(item["content_type"]=="video/mp4")
					downurl = $putio_connection.get("files/#{item['id']}/download").headers["location"]
				else
					downurl = $putio_connection.get("files/#{item['id']}/mp4/download").headers["location"]
				end
				atom.entry do
					atom.title "#{item['name']}"
					atom.link	 "#{downurl}"
				end
			rescue
				
			end
		end
	end
	return list,atom
end

def createFeed
	atom = Builder::XmlMarkup.new(:target => STDOUT, :indent => 2)
	atom.instruct!
	atom.feed "xmlns" => "http://www.w3.org/2005/Atom" do
		atom.id "hurrdurr"																	#CHANGE ME IT HURTS!!!
		atom.updated Time.now.utc.iso8601(0)
  	atom.title "Your Files", :type => "text"
  	atom.link :rel => "self", :href => "/ruby_github.atom" #CHANGE ME IT HURTS!!!
	end
	return atom
end

feed=createFeed
list = $putio_connection.get('files/list').body["files"]
list,atom=createEntries list,feed

