module Boson
  class ReplRunner < Runner
    class <<self
      def start(options={})
        @options = options
        init unless @initialized
        Manager.load(@options[:libraries], load_options) if @options[:libraries]
      end

      def init
        super
        define_autoloader if @options[:autoload_libraries]
        @initialized = true
      end

      def bin_start(repl, libraries)
        start :no_defaults=>true, :libraries=>libraries
        repl = RUBY_PLATFORM =~ /(:?mswin|mingw)/ ? 'irb.bat' : 'irb' unless repl.is_a?(String)
        unless repl.index('/') == 0 || (repl = Util.which(repl))
          $stderr.puts "Repl not found. Please specify full path of repl."
          return
        end
        ARGV.replace ['-f']
        Kernel.load $0 = repl
      end

      def default_libraries
        defaults = super
        unless @options[:no_defaults]
          new_defaults = Boson.repos.map {|e| e.config[:defaults] }.flatten
          new_defaults = detected_libraries if new_defaults.empty?
          defaults += new_defaults
          defaults.uniq!
        end
        defaults
      end
    end
  end
end
  