module Boson
  class ReplRunner < Runner
    class <<self
      def start(options={})
        @options = options
        init unless @initialized
        Library.load(@options[:libraries], @options) if @options[:libraries]
      end

      def bin_start(repl, libraries)
        start :no_defaults=>true, :libraries=>libraries
        repl = RUBY_PLATFORM =~ /(:?mswin|mingw)/ ? 'irb.bat' : 'irb' unless repl.is_a?(String)
        unless repl[/./] == '/' || (repl = Util.which(repl))
          $stderr.puts "Repl not found. Please specify full path of repl."
          return
        end
        ARGV.replace ['-f']
        Kernel.load $0 = repl
      end

      def init
        super
        defaults = boson_libraries
        defaults << IRB::ExtendCommandBundle if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
        defaults += Boson.config[:defaults] unless @options[:no_defaults]
        Library.load(defaults, @options)
        @initialized = true
      end
    end
  end
end
  