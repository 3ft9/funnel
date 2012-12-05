require 'rubygems'
require 'yaml'
require 'pp'
require 'pathname'
require 'twitter'

# We should have been passed a filename containing the app definition (without the .yaml extension)
if ARGV.count == 0
  puts "You need to give me an app definition filename!"
  Process.exit
end

# The app config file is provided by the user, we make the runtime file
app_config_filename = ARGV[0] + '.yaml'
app_state_filename = ARGV[0] + '.state.yaml'

# And that app definition file must exist
if not File::exists?(app_config_filename)
  puts "App definition file \"" + app_config_filename + "\" does not exist!"
  Process.exit
end

# Load the configuration
app_config = YAML::load(File.open(app_config_filename))

# Was it valid yaml?
if not app_config
  puts "App definition file does not contain valid yaml"
  Process.exit
end

# Does it contain a Twitter app key and secret?
if not app_config.has_key?("key") or not app_config.has_key?("secret")
  puts "App definition file is missing the Twitter app key and/or secret"
  Process.exit
end

# Does it contain one or more posts?
if not app_config.has_key?("posts") or not app_config['posts'].kind_of?(Array) or app_config['posts'].length < 1
  puts "App definition file does not contain a valid list of posts"
  Process.exit
end

if File::exists?(app_state_filename)
  app_state = YAML::load(File.open(app_state_filename))
else
  app_state = {
    'oauth' => Twitter::OAuth.new(app_config.key, app_config.secret),
    'next' => 0
  }
  rtoken = app_state['oauth'].request_token.token
  rsecret = app_state['oauth'].request_token.secret

  puts "Authenticate..."
  puts app_state['oauth'].request_token.authorize_url

  print "Enter the PIN: "
  pin = gets.chomp

  begin
    app_state['oauth'].authorize_from_request(rtoken, rsecret, pin)
    File.open(app_state_filename, 'w') { |f| f.puts app_state.to_yaml }
  rescue OAuth::Unauthorized
    puts "Auth failed!"
  end
  Process.exit
end

begin

  twitter = Twitter::Base.new(app_state['oauth'])

  twitter.update(app_config['posts'][app_state['next']])

  app_state['next'] = app_state['next'] + 1
  if app_state['next'] >= app_config['posts'].length
    app_state['next'] = 0
  end

  File.open(app_state_filename, 'w') { |f| f.puts app_state.to_yaml }

rescue OAuth::Unauthorized

  puts "Auth failed!"

end
