module Boson
  class BinRunner < Runner
    class <<self
      def init(options={})
        super
        if main_method = options[:discover]
          libraries_to_load = boson_libraries + all_libraries.partition {|e| e =~ /#{main_method}/ }.flatten
          libraries_to_load.find {|e|
            Library.load [e], options
            Boson.main_object.respond_to? main_method
          }
        end
      end

      def start(args=ARGV)
        if init :discover=>args[0][/\w+/], :verbose=>true
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
    end
  end
end