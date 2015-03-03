require 'thor'
require 'harbor/harborfile'
require 'harbor/client'
require 'harbor/deploy'
require 'harbor/init'
require 'colorize'

module Harbor
  class CLI < Thor
    desc 'status', 'Describes the status of your Harbor environment'
    def status
      load_harborfile!

      puts "=== #{@harborfile.app} ==="
      if @harborfile and @harborfile.valid?
        puts " - Harborfile checks out!".colorize :green
        @harborfile.connect!
        if @harborfile.clients.length == 0
          puts " X No hosts that we're able to contact.".colorize :red
        end
        @harborfile.services.each {|service|
          puts "#{service.name}"
          if service.exists?
            deployed = @harborfile.service_deployed?(service)
            has_port = @harborfile.service_routed?(service)
            color = (deployed && has_port ? :green : :blue)
            puts " - #{service.revision} : #{deployed ? 'Live' : 'Needs Deploy'} #{has_port ? '' : 'Needs Port'}".colorize color
            unless has_port
              puts " X Not listening on a port! Run: `harbor service #{service.port} #{service.name}`".colorize :red
            end
          else
            puts " X Doesn't exist locally!".colorize :red
          end
        }
        @harborfile.clients.each {|client|
          puts " == #{client} =="
          puts "  = Routes ="
          client.routes.each do |route, sha|
            puts "   #{route} -> #{sha}"
          end
          puts "  = Services ="
          client.services.each do |service, port|
            puts "   #{port} -> #{service}"
          end
          puts "  = Deploys = (* are active)"
          client.deploys.each do |deploy|
            routed = client.routes.values.include? deploy
            puts "#{deploy} #{routed ? "*" : ""}"
            # TODO: services within a deploy
          end
          puts "  = Backends ="
          client.backends.each do |backend|
            puts "(#{backend['id']})   #{backend['service']}@#{backend['revision']} -> #{backend['port']}"
            # TODO: stats about flaps and such
          end
        }
      else
        puts " X Harborfile's not valid.".colorize :red
      end

    end

    desc 'deploy', 'Build and launch a new deployment.'
    def deploy
      load_harborfile!
      @harborfile.connect!
      puts "=== Deploying #{@harborfile.app} ==="
      @harborfile.services.each {|service|
        if service.dirty?
          puts "#{service.name} isn't committed and pushed. Aborting deploy.".colorize :red
          exit
        end
      }

      # TODO: parallelize
      @harborfile.services.each {|service|
        Harbor::Deploy.new(service, @harborfile).execute!
      }

      services = Hash[@harborfile.services.collect do |service|
        unless service.dirty?
          [service.name, service.revision.sha]
        end
      end]
      service = client.deploy(services)

      puts "==== YOUR RELEASE IS READY ===="
      puts service.colorize :red
      puts "=============================="
      puts " To cut traffic over to this release,"
      puts "harbor route [DOMAIN] #{service}".yellow
      puts "Where DOMAIN is a specific domain, or 'default'."
      puts "=============================="
    end

    desc 'gc', 'Remove unused routes, releases, deploys, services...'
    def gc
      load_harborfile!
      @harborfile.connect!
      client.deploys.each do |deploy|
        routed = client.routes.values.include? deploy
        unless routed
          if HighLine.new.agree "#{deploy} is unrouted. Remove? (Y/n)".colorize(:red) { |q| q.default = 'Y' }
            client.rm_deploy(deploy)
          end
        end
      end

      # TODO: routes
      # TODO: backends
    end

    desc 'export', 'Export your Harborfile to a Procfile for local development.'
    def export
      load_harborfile!
      @harborfile.services.each {|service|
        # TODO:
      }
    end

    desc 'import', 'Import a Procfile to stub your Harborfile.'
    def import
      # TODO
    end

    desc 'init', 'Initialize a new Harborfile in the currenct directory.'
    def init
      Harbor::Init.run
    end

    # TODO: optional domain
    desc 'route DOMAIN RELEASE', 'Route a domain to a release'
    def route(domain, release)
      load_harborfile!
      @harborfile.connect!
      puts "=== Routing #{domain} to #{release} ==="
      client.route_domain(domain, release)
    end

    desc 'rm_route', 'Remove a domain route'
    def rm_route(domain)
      load_harborfile!
      @harborfile.connect!
      client.unroute_domain(domain)
    end

    desc 'services', 'List out the known services'
    def services
      load_harborfile!
      puts client.services
    end

    desc 'service PORT SERVICE', 'Route a port to a service'
    def service(port, service)
      load_harborfile!
      p client.route_service(port, service)
    end

    desc 'rm_service SERVICE', 'Remove a port to service routing'
    def rm_service(service)
      load_harborfile!
      p client.unroute_service(service)
    end

    desc 'add_backend CWD COMMAND SERVICE REVISION', 'Add a service to the deploy runner'
    def add_backend(cwd, command, service, revision)
      load_harborfile!
      p client.add_backend(cwd, command, service, revision)
    end

    private

      def client
        # BUG: multi-servers
        @client ||= Client.new(@harborfile.servers[0])
      end

      def load_harborfile!
        @harborfile = Harborfile.new('Harborfile')
        begin
          @harborfile.load
        rescue Errno::ENOENT => e
          puts ' !!! No Harborfile found !!!'.colorize :red
          puts 'Run "harbor init" to walk through initializing your Harborfile.'.colorize :red
          exit
        end
      end
  end
end
