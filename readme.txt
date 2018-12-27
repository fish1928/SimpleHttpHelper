# http request sample:

host_ip = '127.0.0.1'
port = '443'
path = 'hello'

# post 127.0.0.1:443/hello/session
#{
#  'username' : 'none',
#  'password' : 'none'
#}

request_helper = HelperModule::SimpleHttpsHelper.new(host_ip, port, path)
request_helper.post('session') do |content|
  content.add_parameters({'username' => 'none', 'password' => 'none'})
end

# get 127.0.0.1:443/hello/userid?name=none
request_helper.get('userid') do |content|
  content_add_parameters({'name' => 'none'})
end

