require 'git'
module Harbor
  class Service

    attr_accessor :name, :port, :cmd, :path

    def initialize(name, config)
      @name = name
      @port = config['port']
      @cmd = config['cmd']
      @path = config['path']

      begin
        @git = Git.open(@path)
      rescue ArgumentError
        @git = nil
      end
    end

    def exists?
      !!@git
    end

    def revision
      dirty? ? 'DIRTY' : @git.log.first
    end

    # (have to get all the running SHAs on any server)
    # probably needs to move to Harborfile.exists_on_server?(service)
    def exists_on_server?
      false
    end

    def dirty?
      not @git or @git.diff('HEAD', '.').size > 0
    end

  end
end
