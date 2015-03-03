require 'yaml'
require 'harbor/service'

# The Harborfile is where we'll encapsulate everything about an entire Harbor
# ecosystem for now - regardless of if it's local or remote, Heroku or native,
# etc.
module Harbor
  class Harborfile

    attr_accessor :services, :file, :clients

    def initialize(path)
      @path = path
      @services = []
      @clients = []
    end

    # TODO: heroku, docker, etc.
    def connect!
      @clients = servers.collect { |server|
        Client.new(server)
      }.compact
    end

    def load
      @file = YAML.load_file(@path)

      # Instantiate Services
      if @file && @file['services']
        @services = @file['services'].collect do |name, config|
          Harbor::Service.new(name, config)
        end
      end
    end

    def valid?
      !!@file
    end

    def app
      @file && @file['harbor'] ? @file['harbor']['app'] : 'default'
    end

    def servers
      @file['harbor']['servers'] if @file && @file['harbor']
    end

    def service_deployed?(service)
      @clients.collect(&:backends).flatten.select {|backend|
        backend['service'] == service.name && backend['revision'] == service.revision.sha
      }.length > 0
    end

    def service_routed?(service)
      @clients.collect(&:services).collect(&:keys).flatten.include? service.name
    end

  end

end

