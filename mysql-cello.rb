require 'sinatra'

get '/' do
  haml :home
end

get '/usage' do
  haml :usage
end
