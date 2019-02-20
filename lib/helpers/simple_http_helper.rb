require 'net/http'
require 'net/https'
require 'json'
require 'ostruct'

module HelperModule

  class SimpleRequestHelper
    attr_reader :host, :port, :path
    attr_accessor :_debug

    def initialize(host, port, path)
      @host, @port, @path = host, port, path
    end

    def set_auth(username, password)
      @auth = OpenStruct.new
      @auth.username = username
      @auth.password = password
    end

    def _request_prefix
      raise NotImplementedError
    end

    def _create_request_sender(host, port)
      raise NotImplementedError
    end

    def _get_base_uri(*args)

      port_str = @port && ":#{@port}"
      path_str = @path
      args_str = args.join('/')
      args_str = "/" + args_str if not args_str.empty?

      URI(URI.escape("#{_request_prefix}://#{@host}#{port_str}/#{path_str}#{args_str}"))
    end

    def _send_request(content_klass, *args, &block)
      uri = _get_base_uri(*args)
      content = content_klass.new(uri)

      block.call(content) if block_given?

      if @_debug
        puts content.get_request.uri
      end

      response = _create_request_sender(@host, @port).start do |http|
        request = content.get_request
        request.basic_auth(@auth.username, @auth.password) if @auth
        http.request(request)
      end

      return SimpleHttpResult.new(response)
    end

    def post(*args, &block)
      return _send_request(PostContent, *args, &block)
    end

    def get(*args, &block)
      return _send_request(GetContent, *args, &block)
    end

    def patch(*args, &block)
      return _send_request(PatchContent, *args, &block)
    end

    def delete(*args, &block)
      return _send_request(DeleteContent, *args, &block)
    end

    def loginsight_get(*args, &block)
      return _send_request(LoginsightGetContent, *args, &block)
    end

    private :_get_base_uri, :_send_request
  end

  class SimpleHttpsHelper < SimpleRequestHelper
    def _request_prefix
      'https'
    end

    def _create_request_sender(host, port)
      Net::HTTP.new(host, port).tap do |http|
        http.use_ssl = true
        #http.set_debug_output($stdout)
      end
    end
  end

  class SimpleHttpHelper < SimpleRequestHelper
    def _request_prefix
      'http'
    end

    def _create_request_sender(host, port)
      Net::HTTP.new(host, port).tap do |http|
        #http.set_debug_output($stdout)
      end
    end
  end

  class SimpleHttpContent
    def initialize(uri)
      @uri = uri
      @headers = {}
    end

    def get_request
      raise NotImplementedError
    end

    def add_parameters(params = {})
      raise NotImplementedError
    end

    def get_request_klass
      raise NotImplementedError
    end

    def add_headers(params = {})
      @headers = params
    end
  end

  class RichBodyContent < SimpleHttpContent
    def get_request
      _request = self.get_request_klass.new(@uri)
      _request.body = @body if @body
      _request.content_type = @content_type if @content_type

      @headers.each_pair do |key, value|
        _request.add_field(key, value)
      end

      _request
    end

    def add_parameters(params = {}, type = 'json')
      if type == 'json'
        @body = params.to_json
        @content_type = 'application/json'
        @type = type
      else
        raise NotImplementedError, "only support json, #{type} is not supported"
      end
    end

    def add_url_parameters(params = {})
      @uri.query = URI.encode_www_form(params)
    end
  end

  class PostContent < RichBodyContent
    def get_request_klass 
      Net::HTTP::Post
    end
  end

  class PatchContent < RichBodyContent
    def get_request_klass
      Net::HTTP::Patch
    end
  end

  class RichUrlContent < SimpleHttpContent
    def get_request
      _request = self.get_request_klass.new(@uri)
      
      @headers.each_pair do |key, value|
        _request.add_field(key, value)
      end

      _request
    end

    def add_parameters(params = {})
      @uri.query = URI.encode_www_form(params)
    end
  end

  class GetContent < RichUrlContent
    def get_request_klass
      Net::HTTP::Get
    end
  end

  class DeleteContent < RichUrlContent
    def get_request_klass
      Net::HTTP::Delete
    end
  end

  class LoginsightGetContent < GetContent
    
    def add_loginsight_parameters(params = {})
      uri_str = @uri.to_s

      params.each_pair do |key, expression|
        if expression.is_a? String
          uri_str += "/#{key}/#{expression}" 
        else
          expressions = expression
          expressions.each do |expression|
            uri_str += "/#{key}/#{expression}"
          end
        end
      end

      @uri = URI(URI.escape(uri_str))
    end
  end


  class SimpleHttpResult
    def initialize(response)
      @response = response
    end

    def to_s
      @response.to_s
    end

    def get_response
      @response
    end

    def is_success?
      @response.code.to_i == 200 || @response.code.to_i == 201
    end

    def error_message
      is_success? ? '' : @response.body
    end

    def get_content
      is_success? ? JSON.parse(@response.body) : nil
    end
  end
end
