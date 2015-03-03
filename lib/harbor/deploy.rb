module Harbor
  class Deploy

    attr_accessor :service, :harborfile

    def initialize(service, harborfile)
      @service = service
      @harborfile = harborfile
    end

    def execute!
      unless @harborfile.service_deployed?(service)
        runner = Runner::Native.new(harborfile.servers[0]) # FIXME
        runner.harborfile = harborfile #FIXME
        runner.run_service(service)
      end
    end

  end

  module Builder

    def compile_steps
      []
    end

    class Base

      attr_accessor :local_path, :remote_path, :user, :host

      def compile_steps
        local_compile_steps + remote_compile_steps.collect {|step|
          "ssh #{@user}@#{@host} \"/bin/bash -l -c \\\"cd #{@remote_path} && #{step}\\\"\""
        }
      end

      def local_compile_steps; []; end
      def remote_compile_steps; []; end
      def files_to_detect; []; end

      def detect
        # We use the local path for speed.
        files_to_detect.any? do |f|
          File.exists? File.join [local_path, f]
        end
      end

      def release
      end
    end
    
    class Ruby < Base
      def files_to_detect
        ['Gemfile']
      end

      def remote_compile_steps
        ['bundle install']
      end
    end

    class Rails < Base
      def files_to_detect
        ['bin/rails'] # TODO: a better way
      end

      def remote_compile_steps
        # TODO: lean on the community to discuss DB migration
        # I personally am against it as it's possibly data munging
        ['RAILS_ENV=production rake assets:precompile']
      end

    end

    class Node < Base
      def files_to_detect
        ['package.json']
      end

      def remote_compile_steps
        ['npm install']
      end
    end

    BUILDERS = [Ruby, Rails, Node]

  end
  
  module Runner
    class Heroku
      # FORESHADOWING
    end

    class Native

      attr_accessor :host, :harborfile

      def initialize(host)
        @host = host['host']
        @config = host
      end

      def buildsteps_for_service(service)
        deploydir = harborfile.file['harbor']['deploy_dir']
        release = "#{service.name}@#{service.revision}"
        
        Builder::BUILDERS.collect { |framework|
          builder = framework.new
          builder.user = harborfile.file['harbor']['deploy_user']
          builder.host = host
          builder.local_path = service.path
          builder.remote_path = "#{deploydir}/#{release}"
          if builder.detect then
            puts "#{builder.to_s} detected - adding buildsteps"
            builder.compile_steps
          end
        }.flatten.compact

      end

      def run_service(service)
        user = harborfile.file['harbor']['deploy_user']
        deploydir = harborfile.file['harbor']['deploy_dir']
        release = "#{service.name}@#{service.revision}"
        puts "Native Runner releasing #{release} to #{@host}"

        # Tarballing up should be faster in most cases, and by using gitarchive
        # we don't have to stress about junk files in the local dir
        release_commands = ["cd #{service.path} && git archive --output /tmp/#{release}.tgz --prefix=#{release}/ master",
        "scp /tmp/#{release}.tgz #{user}@#{@host}:#{deploydir}/",
        "ssh #{user}@#{@host} \"cd #{deploydir}; tar -zxf #{release}.tgz\""]

        # TODO: (lean heavily on heroku buildpacks to ensure we've got the correct env installed)
        # These should take the place of the Builder class before a 1.0 release.

        release_commands += buildsteps_for_service(service)
        release_commands.each do |command|
          puts " $ #{command}"
          output = `#{command}`
          unless $?.success? then
            p output
          end
        end
        
        # Tell Harbor to go fire it up, it's ready.
        client = Harbor::Client.new(@config)
        client.add_backend("#{deploydir}/#{release}", service.cmd, service.name, service.revision.sha)
      end

    end
  end
end
