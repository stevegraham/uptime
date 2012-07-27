require 'bundler'
require 'eventmachine'
require 'em-http-request'
require 'em-synchrony'
require 'twilio-rb'

$stdout.sync = true
puts 'go time'

Twilio::Config.setup \
  account_sid: ENV['TWILIO_ACCOUNT_SID'],
  auth_token: ENV['TWILIO_AUTH_TOKEN']

def send_sms body
  Twilio::SMS.create from: ENV['TWILIO_NUMBER'], to: ENV['SMS_RECIPIENT'],
    body: "#{Time.now}: #{body}"
end

EM.run do
  EM.add_periodic_timer(ENV['POLL_INTERVAL'].to_i) do
    puts 'checking...'
    req = EM::HttpRequest.new(ENV['SITE_URL']).get

    req.errback do
      puts 'site unreachable. sending sms'
      send_sms "#{ENV['SITE_URL']} is unreachable"
    end

    req.callback do
      puts "status #{req.response_header.status.to_i}"
      if (400..599).include?(req.response_header.status.to_i) && !@down
        puts 'site down'
        @down = true
        send_sms "#{ENV['SITE_URL']} is down! Response code: #{req.response_header.status}"
      elsif (200..399).include?(req.response_header.status.to_i) && @down
        puts 'site up'
        @down = false
        send_sms "#{ENV['SITE_URL']} is back up"
      end
    end
  end
end
