#!/usr/bin/env ruby

# (c) 2011 Rdio Inc
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'sinatra'
require 'uri'
$LOAD_PATH << './lib'
require 'rdio'

RDIO_CONSUMER_KEY = ENV['RDIO_CONSUMER_KEY']
RDIO_CONSUMER_SECRET = ENV['RDIO_CONSUMER_SECRET']

class App < Sinatra::Base
  enable :sessions
  get '/' do
    access_token = session[:at]
    access_token_secret = session[:ats]
    if access_token and access_token_secret
      rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                      [access_token, access_token_secret])

      user_key  = rdio.call('currentUser')['result']['key']
      play_data = rdio.call('get', { :keys => user_key, :extras => 'lastSongPlayed,lastSongPlayTime'})['result'][user_key]

      play_time = play_data['lastSongPlayTime']
      song_key = play_data['lastSongPlayed']['key']

      song = rdio.call('get', { :keys => song_key, :extras => 'bigIcon'})['result'][song_key]

      response = "
      <html><head><title>Now Playing</title></head><body>
      <img src='%s' />
      <h1>%s</h1>
      <h2>%s</h2>
      <h3>%s</h3>
      " % [song['bigIcon'], song['name'], song['album'], song['artist']]
      response += '</body></html>'
      return response
    else
      redirect to('/login')
    end
  end

  get '/login' do
    session.clear
    # begin the authentication process
    rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET])
    callback_url = (URI.join request.url, '/callback').to_s
    url = rdio.begin_authentication(callback_url)
    # save our request token in the session
    session[:rt] = rdio.token[0]
    session[:rts] = rdio.token[1]
    # go to Rdio to authenticate the app
    redirect url
  end

  get '/callback' do
    # get the state from cookies and the query string
    request_token = session[:rt]
    request_token_secret = session[:rts]
    verifier = params[:oauth_verifier]
    # make sure we have everything we need
    if request_token and request_token_secret and verifier
      # exchange the verifier and request token for an access token
      rdio = Rdio.new([RDIO_CONSUMER_KEY, RDIO_CONSUMER_SECRET],
                      [request_token, request_token_secret])
      rdio.complete_authentication(verifier)
      # save the access token in cookies (and discard the request token)
      session[:at] = rdio.token[0]
      session[:ats] = rdio.token[1]
      session.delete(:rt)
      session.delete(:rts)
      # go to the home page
      redirect to('/')
    else
      # we're missing something important
      redirect to('/logout')
    end
  end

  get '/logout' do
    session.clear
    redirect to('/')
  end
end

App.run! :host => 'localhost', :port => ENV['PORT']