# Extracts arguments and their default values from methods either by
# by scraping a method's text or with method_added and brute force eval (thanks to
# {eigenclass}[http://eigenclass.org/hiki/method+arguments+via+introspection]).
module Boson::ArgumentInspector
  extend self
  # Returns same argument arrays as scrape_with_eval but argument defaults haven't been evaluated.
  def scrape_with_text(file_string, meth)
    tabspace = "[ \t]"
    if match = /^#{tabspace}*def#{tabspace}+#{meth}#{tabspace}*($|\(?\s*([^\)]+)\s*\)?\s*$)/.match(file_string)
      (match.to_a[2] || '').split(/\s*,\s*/).map {|e| e.split(/\s*=\s*/)}
    end
  end

  # Max number of arguments extracted per method with scrape_with_eval
  MAX_ARGS = 10
  # Scrapes non-private methods for argument names and default values.
  # Returns arguments as array of argument arrays with optional default value as a second element.
  # ====Examples:
  #   def meth1(arg1, arg2='val', options={}) -> [['arg1'], ['arg2', 'val'], ['options', {}]]
  #   def meth2(*args) -> [['*args']]
  def scrape_with_eval(meth, klass, object)
    unless %w[initialize].include?(meth.to_s)
      return if class << object; private_instance_methods(true).map {|e| e.to_s } end.include?(meth.to_s)
    end
    params, values, arity, num_args = trace_method_args(meth, klass, object)
    return if local_variables == params # nothing new found
    format_arguments(params, values, arity, num_args)
    rescue Exception
      # puts "#{klass}.#{meth}: #{$!.message}"
    ensure
      set_trace_func(nil)
  end

  # process params + values to return array of argument arrays
  def format_arguments(params, values, arity, num_args) #:nodoc:
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

  def trace_method_args(meth, klass, object) #:nodoc:
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