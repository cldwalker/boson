# Handles reading and extracting command description and usage from file libraries
# comment descriptions inspired by http://github.com/pragdavespc/rake/commit/45231ac094854da9f4f2ac93465ed9b9ca67b2da
module Boson::Inspector
  extend self
  # returns file and line no of method given caller array
  def find_method_locations(stack)
    if (line = stack.find {|e| e =~ /in `load_source'/ })
      (line =~ /^(.*):(\d+)/) ? [$1, $2.to_i] : nil
    end
  end

  def add_meta_methods
    ::Module.module_eval %[
      def new_method_added(method)
        if @desc
          @_descriptions[method.to_s] = @desc
          @desc = nil
        end
        if @opts
          @_options[method.to_s] = @opts
          @opts = nil
        end
        if @opts.nil? || @desc.nil?
          @_method_locations ||= {}
          if (result = Boson::Inspector.find_method_locations(caller))
            @_method_locations[method.to_s] = result
          end
        end
        if instance_of? Module
          o = Object.new
          o.extend(self)
          Boson::Inspector.output_method_info(self, o, method, false)
        end
      end

      def options(opts)
        @_options ||= {}
        @opts = opts
      end

      def desc(description)
        @_descriptions ||= {}
        @desc = description
      end

      alias_method :_old_method_added, :method_added
      alias_method :method_added, :new_method_added
    ]
  end

  def remove_meta_methods
    ::Module.module_eval %[
      remove_method :desc
      alias_method :method_added, :_old_method_added
    ]
  end

  def description_from_file(file_string, line)
    lines = file_string.split("\n")
    line -= 2
    (lines[line] =~ /^\s*#\s*(?!\s*options)(.*)/) ? $1 : nil
  end

  def options_from_file(file_string, line)
    lines = file_string.split("\n")
    start_line = line - 3
    (start_line..start_line +1).find {|line|
      if options = (lines[line] =~ /^\s*#\s*options\s*(.*)/) ? $1 : nil
        options = "{#{options}}" unless options[/^\s*\{/]
        return begin eval(options); rescue(Exception); nil end
      end
    }
  end

  def command_usage(name)
    return "Command not loaded" unless (command = Boson.command(name.to_s) || Boson.command(name.to_s, :alias))
    return "Library for #{command_obj.name} not found" unless lib = Boson.library(command.lib)
    return "File for #{lib.name} library not found" unless File.exists?(lib.library_file || '')
    tabspace = "[ \t]"
    file_string = Boson::FileLibrary.read_library_file(lib.library_file)
    if match = /^#{tabspace}*def#{tabspace}+#{command.name}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(file_string)
      "#{name} "+ (match.to_a[2] || '').split(/\s*,\s*/).map {|e| "[#{e}]"}.join(' ')
    else
      "Command not found in file"
    end
  end

  MAX_ARGS = 10
  # from http://eigenclass.org/hiki/method+arguments+via+introspection
  def output_method_info(klass, object, meth, is_singleton = false)
    return if $__method_args_off
    file = line = params = values = nil
    unless %w[initialize].include?(meth.to_s)
      if is_singleton
        return if class << klass; private_instance_methods(true) end.include?(meth.to_s)
      else
        return if class << object; private_instance_methods(true) end.include?(meth.to_s)
      end
    end
    arity = is_singleton ? object.method(meth).arity : klass.instance_method(meth).arity
    set_trace_func lambda{|event, file, line, id, binding, classname|
      begin
        #puts "!EVENT: #{event} #{classname}##{id}, #{file} #{line}"
        #puts "(#{self} #{meth})"
        if event[/call/] && classname == klass && id == meth
          params = eval("local_variables", binding)
          values = eval("local_variables.map{|x| eval(x)}", binding)
          #puts "EVENT: #{event} #{classname}##{id}"
          throw :done
        end
      rescue Exception
      end
    }
    variadic_with_block = false
    if arity >= 0
      num_args = arity
      catch(:done){ object.send(meth, *(0...arity)) }
    else
      num_args = 0
      # determine number of args (including splat & block)
      MAX_ARGS.downto(arity.abs - 1) do |i|
        catch(:done) do 
          begin
            object.send(meth, *(0...i)) 
          rescue Exception
          end
        end
        # all nils if there's no splat and we gave too many args
        next if !values || values.compact.empty? 
        k = nil
        values.each_with_index{|x,j| break (k = j) if Array === x}
        if k
          num_args = k+1
        else
          num_args = i
        end
        break
      end
      # determine if it's got a block arg
=begin
      30.downto(arity.abs - 1) do |i|
        catch(:done) { object.send(meth, *(0...i)) }
        next if values.compact.empty?
        variadic_with_block = true if values[-1] == nil
      end
=end
      args = (0...arity.abs-1).to_a
      catch(:done) do 
        args.empty? ? object.send(meth) : object.send(meth, *args)
      end
    end
    #p params, values
    set_trace_func(nil)

    if local_variables == params
      puts "#{klass}#{is_singleton ? "." : "#"}#{meth} (...)"
      return
    end

    fmt_params = lambda do |arr, arity|
      arr.inject([[], 0]) do |(a, i), x|
        if Array === values[i] 
          [a << "*#{x}", i+1] 
        else
          if arity < 0 && i >= arity.abs - 1
            [a << "#{x} = #{values[i].inspect}", i + 1]
          else
            [a << x, i+1]
          end
        end
      end.first.join(", ")
    end
    params ||= []
    params = params[0,num_args]
    #unfortunately, there's no way to tell the block arg from the first local
    #since its value will be nil even if we pass a block
    #if arity >= 0 && params[arity] # or variadic_with_block
    #  arg_desc = "(#{fmt_params.call(params[0..-2], arity)}, &#{params.last})"
    #else
    arg_desc = "(#{fmt_params.call(params, arity)})"
    #end


    puts "#{klass}#{is_singleton ? "." : "#" }#{meth} #{arg_desc}"
    rescue Exception
      #puts "GOT EXCEPTION while processing #{klass} #{meth}"
      #puts $!.message
      #puts $!.backtrace
      puts "#{klass}#{is_singleton ? "." : "#"}#{meth} (...)"
    ensure
      set_trace_func(nil)
  end
end