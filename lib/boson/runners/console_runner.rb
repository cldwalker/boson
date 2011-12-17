module Boson
  # Runner used when starting irb. To use in irb, drop this in your ~/.irbrc:
  #   require 'boson'
  #   Boson.start
  class ConsoleRunner < Runner
    class <<self
      # Starts Boson by loading configured libraries. If no default libraries are specified in the config,
      # it will load up all detected libraries. Options:
      # [:libraries] Array of libraries to load.
      # [:verbose] Boolean to be verbose about libraries loading. Default is true.
      # [:no_defaults] Boolean or :all which turns off loading default libraries. If set to true,
      #                effects loading user's console default libraries. If set to :all, effects
      #                all libraries including boson's. Default is false.
      # [:autoload_libraries] Boolean which makes any command execution easier. It redefines
      #                       method_missing on Boson.main_object so that commands with unloaded
      #                       libraries are automatically loaded. Default is false.
      def start(options={})
        super
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
          abort "Console not found. Please specify full path in config[:console]."
        else
          load_repl(repl)
        end
      end

      def load_repl(repl) #:nodoc:
        ARGV.replace ['-f']
        $progname = $0
        alias $0 $progname
        Kernel.load $0 = repl
      end

      def init #:nodoc:
        super
        define_autoloader if @options[:autoload_libraries]
        @initialized = true
      end

      def default_libraries #:nodoc:
        return [] if @options[:no_defaults] == :all
        return super if @options[:no_defaults]
        defaults = super + Boson.repos.map {|e| e.config[:console_defaults] }.flatten
        defaults += detected_libraries if defaults.empty?
        defaults.uniq
      end
    end
  end
end
