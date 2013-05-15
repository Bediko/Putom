require 'builder'
require 'faraday'
require 'faraday_middleware'
require 'time'

def putio_files(putio_connection, folder_id = nil, &block)
  begin
    directory = putio_connection.get do |req|
      req.url 'files/list'
      req.params['parent_id'] = folder_id if folder_id
    end
  rescue Faraday::Error::ResourceNotFound
    return
  end

  directory.body['files'].each do |file|
    if file['content_type'] == 'application/x-directory'
      putio_files(putio_connection, file['id'], &block)
    else
      begin
        download = putio_connection.get do |req|
          if file['content_type'] == 'video/mp4'
            req.url "files/#{file['id']}/download"
          else
            req.url "files/#{file['id']}/mp4/download"
          end
        end

        file['download_url'] = download.headers['location']
        yield file
      rescue Faraday::Error::ResourceNotFound
      rescue Faraday::Error::ClientError
        retry
      end
    end
  end
end

token = IO.read('token').strip
putio_connection = Faraday.new('https://api.put.io/v2/') do |faraday|
  faraday.request :oauth2, token, param_name: :oauth_token
  faraday.response :json, content_type: /\bjson$/
  faraday.response :raise_error
  faraday.adapter Faraday.default_adapter
end

output = open('atom', 'w')
feed = Builder::XmlMarkup.new(target: output, indent: 2)
feed.instruct!

feed.feed xmlns: 'http://www.w3.org/2005/Atom' do
  feed.id 'hurrdurr'                                  #CHANGE ME IT HURTS!!!
  feed.updated Time.now.utc.iso8601(0)
  feed.title 'Your Files', type: 'text'
  feed.link rel: 'self', href: '/ruby_github.atom' #CHANGE ME IT HURTS!!!

  putio_files(putio_connection) do |file|
    feed.entry do
      feed.id "urn:put-io:files:#{file['id']}"
      feed.title file['name']
      feed.link href: file['download_url'], rel: 'alternate'
      feed.author do
        feed.name 'Putover'
      end
      feed.content file['name']
      feed.published "#{file['created_at']}Z"
      feed.updated "#{file['created_at']}Z"
    end
  end
end

output.close