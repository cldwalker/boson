# Extracts arguments and their default values from methods either at method_added time
# compliments of http://eigenclass.org/hiki/method+arguments+via+introspection
# or by simply scraping a file.
module Boson::ArgumentInspector
  extend self
  # produces same argument arrays as determine_method_args
  def arguments_from_file(file_string, meth)
    tabspace = "[ \t]"
    if match = /^#{tabspace}*def#{tabspace}+#{meth}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(file_string)
      (match.to_a[2] || '').split(/\s*,\s*/).map {|e| e.split(/\s*=\s*/)}
    end
  end

  MAX_ARGS = 10 # max number of arguments extracted for a method
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