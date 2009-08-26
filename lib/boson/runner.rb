module Boson
  module Runner
    extend self
    def bin_init(options={})
      basic_init
      if main_method = options[:discover]
        libraries_to_load = boson_libraries + all_libraries.partition {|e| e =~ /#{main_method}/ }.flatten
        libraries_to_load.find {|e|
          Library.load [e], options
          Boson.main_object.respond_to? main_method
        }
      end
    end

    def start(args=ARGV)
      if bin_init :discover=>args[0][/\w+/], :verbose=>true
        if args[0].include?('.')
          meth1, meth2 = args.shift.split('.', 2)
          dispatcher = Boson.invoke(meth1)
          args.unshift meth2
        else
          dispatcher = Boson.main_object
        end
        output = dispatcher.send(*args)
        puts Hirb::View.render_output(output) || output.inspect
      else
        $stderr.puts "Error: No command found to execute"
      end
    end

    def basic_init
      Hirb.enable(:config_file=>File.join(Boson.dir, 'config', 'hirb.yml'))
      add_load_path
    end

    def init(options={})
      Library.create all_libraries, options
      basic_init
      load_default_libraries(options)
      @initialized = true
    end

    def add_load_path
      if Boson.config[:add_load_path] || File.exists?(File.join(Boson.dir, 'lib'))
        $: <<  File.join(Boson.dir, 'lib') unless $:.include? File.expand_path(File.join(Boson.dir, 'lib'))
      end
    end

    def load_default_libraries(options)
      defaults = boson_libraries
      defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
      defaults += Boson.config[:defaults] if Boson.config[:defaults]
      Library.load(defaults, options)
    end

    def boson_libraries
      [Boson::Commands::Core, Boson::Commands::Namespace]
    end

    def detected_libraries
      Dir[File.join(Boson.dir, 'commands', '**/*.rb')].map {|e| e.gsub(/.*commands\//,'').gsub('.rb','') }
    end

    def all_libraries
      (detected_libraries + Boson.config[:libraries].keys).uniq
    end

    def activate(options={})
      init(options) unless @initialized
      libraries = options[:libraries] || []
      Library.load(libraries, options)
    end
  end
end
