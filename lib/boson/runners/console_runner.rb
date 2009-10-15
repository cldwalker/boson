module Boson
  # Runner used when starting irb. To use in irb, drop this in your ~/.irbrc:
  #   require 'boson'
  #   Boson.start
  class ConsoleRunner < Runner
    class <<self
      # Starts Boson by loading configured libraries. If no default libraries are specified in the config,
      # it will load up all detected libraries.
      # ==== Options
      # [:libraries] Array of libraries to load.
      # [:verbose] Boolean to be verbose about libraries loading. Default is true.
      # [:no_defaults] Boolean which turns off loading any default libraries. Default is false.
      # [:autoload_libraries] Boolean which makes any command execution easier. It redefines
      #                       method_missing on Boson.main_object so that commands with unloaded
      #                       libraries are automatically loaded. Default is false.
      def start(options={})
        @options = {:verbose=>true}.merge options
        init unless @initialized
        Manager.load(@options[:libraries], load_options) if @options[:libraries]
      end

      # Loads libraries and then starts irb (or the configured console) from the commandline.
      def bin_start(repl, libraries)
        start :no_defaults=>true, :libraries=>libraries
        repl = Boson.repo.config[:console] if Boson.repo.config[:console]
        repl = RUBY_PLATFORM =~ /(:?mswin|mingw)/ ? 'irb.bat' : 'irb' unless repl.is_a?(String)
        unless repl.index('/') == 0 || (repl = Util.which(repl))
          $stderr.puts "Console not found. Please specify full path in config[:console]."
          return
        end
        ARGV.replace ['-f']
        Kernel.load $0 = repl
      end

      def init #:nodoc:
        super
        define_autoloader if @options[:autoload_libraries]
        @initialized = true
      end

      def default_libraries #:nodoc:
        defaults = super
        unless @options[:no_defaults]
          new_defaults = Boson.repos.map {|e| e.config[:console_defaults] }.flatten
          new_defaults = detected_libraries if new_defaults.empty?
          defaults += new_defaults
          defaults.uniq!
        end
        defaults
      end
    end
  end
end
  