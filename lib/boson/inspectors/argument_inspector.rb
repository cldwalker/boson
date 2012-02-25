# Extracts arguments and their default values from methods either by
# by scraping a method's text or with method_added and brute force eval (thanks to
# {eigenclass}[http://eigenclass.org/hiki/method+arguments+via+introspection]).
module Boson::ArgumentInspector
  extend self
  # Returns same argument arrays as scrape_with_eval but argument defaults haven't been evaluated.
  def scrape_with_text(file_string, meth)
    tabspace = "[ \t]"
    if match = /^#{tabspace}*def#{tabspace}+(?:\w+\.)?#{Regexp.quote(meth)}#{tabspace}*($|(?:\(|\s+)([^\n\)]+)\s*\)?\s*$)/.match(file_string)
      (match.to_a[2] || '').strip.split(/\s*,\s*/).map {|e| e.split(/\s*=\s*/)}
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
    params, values, arity, num_args = trace_method_args(meth, klass, object)
    return if local_variables == params # nothing new found
    format_arguments(params, values, arity, num_args)
    rescue Exception
      print_debug_message(klass, meth) if Boson::Runner.debug
  end

  def print_debug_message(klass, meth) #:nodoc:
    warn "DEBUG: Error while scraping arguments from #{klass.to_s[/\w+$/]}##{meth}: #{$!.message}"
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
          [a << [x.to_s, values[i]], i + 1]
        else
          [a << [x.to_s], i+1]
        end
      end
    end.first
  end

  def trace_method_args(meth, klass, object) #:nodoc:
    params = values = nil
    arity = klass.instance_method(meth).arity
    # hollowed out method returns only parameters and values
    if arity >= 0
      num_args = arity
      params, values = object.send(meth, *(0...arity))
    else
      num_args = 0
      # determine number of args (including splat & block)
      MAX_ARGS.downto(arity.abs - 1) do |i|
        begin
          params, values = object.send(meth, *(0...i))
        rescue Exception
        end
        # all nils if there's no splat and we gave too many args
        next if !values || values.compact.empty?
        k = nil
        values.each_with_index{|x,j| break (k = j) if Array === x}
        num_args = k ? k+1 : i
        break
      end
      args = (0...arity.abs-1).to_a
      params, values = args.empty? ? object.send(meth) : object.send(meth, *args)
    end
    return [params, values, arity, num_args]
  end
end
