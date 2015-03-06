require 'rest_client'
require 'json'
require 'net/ssh/gateway'

module Harbor
  # class WebClient
  # This speaks to the Harbor REST service for routing.
  class Client
   
    def initialize(config)
      @host = config['host'] || 'http://127.0.0.1'
      @port = config['port'] || '6060'

      if config['type'] == 'http+ssh'
        # TODO: reuse the SSH connection we need for the copying? (Maybe not, this is just for control ports)
        @ssh = Net::SSH::Gateway.new(@host, 'apps')
        @gateway = @ssh.open('127.0.0.1', @port)
        @host = '127.0.0.1'
        @port = @gateway
      end
    end

    def status
      RestClient.get([host, 'status'].join('/')) do |response, req, res|
        response
      end
    end

    def to_s
      host
    end

    def services
      @services ||= get('services') do |response|
        Hash[response.collect do |service|
          [service['service'], service['port']]
        end]
      end
    end

    def route_service(port, service)
      @services = nil
      put("services/#{port}", service: service) do |response|
        response
      end
    end

    def unroute_service(service)
      port = services[service]
      if port then
        delete("services/#{port}") do |response|
          response
        end
      else
        "Not routed"
      end
    end

    def route_domain(domain, release)
      @routes = nil
      put("routes/#{domain}", release: release) do |response|
        response
      end
    end

    def unroute_domain(domain)
      @routes = nil
      delete("routes/#{domain}") do |response|
        response
      end
    end
  
    def routes
      @routes ||= get('routes') do |response|
        response
      end
    end

    def backends
      get('backends') do |response|
        response # TODO: indifferent access :/
      end
    end

    def add_backend(cwd, command, service, revision)
      backend = {
        cwd: cwd,
        command: command,
        service: service,
        revision: revision
      }
      put("backends", backend) do |response|
        response
      end
    end

    def deploy(services)
      put("deploys", deploy: services) do |response|
        response
      end
    end

    def deploys
      get('deploys') do |response|
        response
      end
    end

    def rm_deploy(deploy)
      delete("deploys/#{deploy}") do |response|
        response
      end
    end

    private

      def host
        # TODO: smarter joining
        "#{@host}:#{@port}"
      end

      def delete(endpoint)
        RestClient.delete([host, endpoint].join('/')) do |response, req, res|
          response
        end
      end

      def put(endpoint, body)
        RestClient.put([host, endpoint].join('/'), body) do |response, req, res|
          response
        end
      end

      def get(endpoint)
        # TODO: join host + endpoint correctly
        RestClient.get([host, endpoint].join('/')) do |response, req, res|
          begin
            result = JSON.parse response
          rescue JSON::ParserError
            result = ''
          end

          yield result
        end
      end
  end
end
