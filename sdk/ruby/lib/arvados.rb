require 'rubygems'
require 'google/api_client'
require 'active_support/inflector'
require 'json'

ActiveSupport::Inflector.inflections do |inflect|
  inflect.irregular 'specimen', 'specimens'
  inflect.irregular 'human', 'humans'
end

module Kernel
  def suppress_warnings
    original_verbosity = $VERBOSE
    $VERBOSE = nil
    result = yield
    $VERBOSE = original_verbosity
    return result
  end
end

class Arvados

  class TransactionFailedError < StandardError
  end

  @@debuglevel = 0
  class << self
    attr_accessor :debuglevel
  end

  def initialize(opts={})
    @application_version ||= 0.0
    @application_name ||= File.split($0).last

    @arvados_api_version = opts[:api_version] ||
      ENV['ARVADOS_API_VERSION'] ||
      'v1'
    @arvados_api_host = opts[:api_host] ||
      ENV['ARVADOS_API_HOST'] or
      raise "#{$0}: no :api_host or ENV[ARVADOS_API_HOST] provided."
    @arvados_api_token = opts[:api_token] ||
      ENV['ARVADOS_API_TOKEN'] or
      raise "#{$0}: no :api_token or ENV[ARVADOS_API_TOKEN] provided."

    if (opts[:api_host] ? opts[:suppress_ssl_warnings] :
        ENV['ARVADOS_API_HOST_INSECURE'])
      suppress_warnings do
        OpenSSL::SSL.const_set 'VERIFY_PEER', OpenSSL::SSL::VERIFY_NONE
      end
    end

    # Define a class and an Arvados instance method for each Arvados
    # resource. After this, self.job will return Arvados::Job;
    # self.job.new() and self.job.find() will do what you want.
    _arvados = self
    namespace_class = Arvados.const_set "A#{self.object_id}", Class.new
    self.arvados_api.schemas.each do |classname, schema|
      next if classname.match /List$/
      klass = Class.new(Arvados::Model) do
        def self.arvados
          @arvados
        end
        def self.api_models_sym
          @api_models_sym
        end
        def self.api_model_sym
          @api_model_sym
        end
      end

      # Define the resource methods (create, get, update, delete, ...)
      self.
        arvados_api.
        send(classname.underscore.split('/').last.pluralize.to_sym).
        discovered_methods.
        each do |method|
        class << klass; self; end.class_eval do
          define_method method.name do |*params|
            self.api_exec(method.name.to_sym, *params)
          end
        end
      end

      # Give the new class access to the API
      klass.instance_eval do
        @arvados = _arvados
        # These should be pulled from the discovery document instead:
        @api_models_sym = classname.underscore.split('/').last.pluralize.to_sym
        @api_model_sym = classname.underscore.split('/').last.to_sym
      end

      # Create the new class in namespace_class so it doesn't
      # interfere with classes created by other Arvados objects. The
      # result looks like Arvados::A26949680::Job.
      namespace_class.const_set classname, klass

      self.class.class_eval do
        define_method classname.underscore do
          klass
        end
      end
    end
  end

  class Google::APIClient
    def discovery_document(api, version)
      api = api.to_s
      return @discovery_documents["#{api}:#{version}"] ||=
        begin
          response = self.execute!(
                                   :http_method => :get,
                                   :uri => self.discovery_uri(api, version),
                                   :authenticated => false
                                   )
          response.body.class == String ? JSON.parse(response.body) : response.body
        end
    end
  end

  def client
    @client ||= Google::APIClient.
      new(:host => @arvados_api_host,
          :application_name => @application_name,
          :application_version => @application_version.to_s)
  end

  def arvados_api
    @arvados_api ||= self.client.discovered_api('arvados', @arvados_api_version)
  end

  def self.debuglog(message, verbosity=1)
    $stderr.puts "#{File.split($0).last} #{$$}: #{message}" if @@debuglevel >= verbosity
  end

  class Model
    def self.arvados_api
      arvados.arvados_api
    end
    def self.client
      arvados.client
    end
    def self.debuglog(*args)
      arvados.class.debuglog *args
    end
    def debuglog(*args)
      self.class.arvados.class.debuglog *args
    end
    def self.api_exec(method, parameters={})
      parameters = parameters.
        merge(:api_token => ENV['ARVADOS_API_TOKEN'])
      parameters.each do |k,v|
        parameters[k] = v.to_json if v.is_a? Array or v.is_a? Hash
      end
      result = client.
        execute(:api_method => arvados_api.send(api_models_sym).send(method),
                :authenticated => false,
                :parameters => parameters)
      resp = JSON.parse result.body, :symbolize_names => true
      if resp[:errors]
        raise Arvados::TransactionFailedError.new(resp[:errors])
      elsif resp[:uuid] and resp[:etag]
        self.new(resp)
      elsif resp[:items].is_a? Array
        resp.merge(items: resp[:items].collect do |i|
                     self.new(i)
                   end)
      else
        resp
      end
    end

    def []=(x,y)
      @attributes_to_update[x] = y
      @attributes[x] = y
    end
    def [](x)
      if @attributes[x].is_a? Hash or @attributes[x].is_a? Array
        # We won't be notified via []= if these change, so we'll just
        # assume they are going to get changed, and submit them if
        # save() is called.
        @attributes_to_update[x] = @attributes[x]
      end
      @attributes[x]
    end
    def save
      @attributes_to_update.keys.each do |k|
        @attributes_to_update[k] = @attributes[k]
      end
      j = self.class.api_exec :update, {
        :uuid => @attributes[:uuid],
        self.class.api_model_sym => @attributes_to_update.to_json
      }
      unless j.respond_to? :[] and j[:uuid]
        debuglog "Failed to save #{self.to_s}: #{j[:errors] rescue nil}", 0
        nil
      else
        @attributes_to_update = {}
        @attributes = j
      end
    end

    protected

    def initialize(j)
      @attributes_to_update = {}
      @attributes = j
    end
  end
end
