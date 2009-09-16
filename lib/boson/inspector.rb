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

  def current_method_has_options?(meth, method_location)
    return false if meth == 'method_added' && method_location[0].include?('libraries/file_library.rb')
    method_location && File.exists?(method_location[0]) &&
      options_from_file(Boson::FileLibrary.read_library_file(method_location[0]), method_location[1])
  end

  def add_meta_methods
    @enabled = true
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

        # if module && options exists for method
        if instance_of?(Module) && (@_options && @_options.key?(method.to_s)) ||
          (@_method_locations && Boson::Inspector.current_method_has_options?(method.to_s, @_method_locations[method.to_s]))

          @_method_args ||= {}
          o = Object.new
          o.extend(self)
          # private methods return nil
          if (val = Boson::Inspector.determine_method_args(method, self, o))
            @_method_args[method.to_s] = val
          end
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
      remove_method :options
      alias_method :method_added, :_old_method_added
    ]
    @enabled = false
  end

  def enabled?; @enabled; end

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

  # produces same argument arrays as determine_method_args
  def arguments_from_file(file_string, meth)
    tabspace = "[ \t]"
    if match = /^#{tabspace}*def#{tabspace}+#{meth}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(file_string)
      (match.to_a[2] || '').split(/\s*,\s*/).map {|e| e.split('=')}
    end
  end

  MAX_ARGS = 10 # max number of arguments extracted for a method
  # from http://eigenclass.org/hiki/method+arguments+via+introspection
  # returns argument arrays which have an optional 2nd element with an argument's default value
  def determine_method_args(meth, klass, object)
    unless %w[initialize].include?(meth.to_s)
      return if class << object; private_instance_methods(true) end.include?(meth.to_s)
    end
    params, values, arity, num_args = trace_method_args(meth, klass, object)
    return if local_variables == params # nothing new found
    format_arguments(params, values, arity, num_args)
    rescue Exception
      #puts "#{klass}.#{methd}: #{$!.message}"
    ensure
      set_trace_func(nil)
  end

  # process params + values to return array of argument arrays
  def format_arguments(params, values, arity, num_args)
    params ||= []
    params = params[0,num_args]
    params.inject([[], 0]) do |(a, i), x|
      if Array === values[i]
        [a << ["*#{x}"], i+1]
      else
        if arity < 0 && i >= arity.abs - 1
          [a << [x, values[i]], i + 1]
        else
          [a << [x], i+1]
        end
      end
    end.first
  end

  def trace_method_args(meth, klass, object)
    file = line = params = values = nil
    arity = klass.instance_method(meth).arity
    set_trace_func lambda{|event, file, line, id, binding, classname|
      begin
        if event[/call/] && classname == klass && id == meth
          params = eval("local_variables", binding)
          values = eval("local_variables.map{|x| eval(x)}", binding)
          throw :done
        end
      rescue Exception
      end
    }
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
        num_args = k ? k+1 : i
        break
      end
      args = (0...arity.abs-1).to_a
      catch(:done) do 
        args.empty? ? object.send(meth) : object.send(meth, *args)
      end
    end
    set_trace_func(nil)
    return [params, values, arity, num_args]
  end
end