module Boson
  # Handles {Hirb}[http://tagaholic.me/hirb/]-based views.
  module View
    extend self

    # Enables hirb and reads a config file from the main repo's config/hirb.yml.
    def enable
      Hirb::View.enable(:config_file=>File.join(Boson.repo.config_dir, 'hirb.yml')) unless @enabled
      @enabled = true
    end

    def toggle_pager
      Hirb::View.toggle_pager
    end

    # Renders any object via Hirb. Options are passed directly to
    # {Hirb::Console.render_output}[http://tagaholic.me/hirb/doc/classes/Hirb/Console.html#M000011].
    def render(object, options={})
      if silent_object?(object)
        puts(object.inspect) unless options[:silence_booleans]
      else
        render_object(object, options)
      end
    end

    def silent_object?(obj)
      [nil,false,true].include?(obj)
    end

    def render_object(object, options={}) #:nodoc:
      options[:class] ||= :auto_table
      if object.is_a?(Array) && object.size > 0 && (sort = options.delete(:sort))
        begin
          sort_lambda = object[0].is_a?(Hash) ? (object[0][sort].respond_to?(:<=>) ?
            lambda {|e| e[sort] } : lambda {|e| e[sort].to_s }) :
            (object[0].send(sort).respond_to?(:<=>) ? lambda {|e| e.send(sort) || ''} :
            lambda {|e| e.send(sort).to_s })
          object = object.sort_by &sort_lambda
          object = object.reverse if options[:reverse_sort]
        rescue NoMethodError, ArgumentError
          $stderr.puts "Sort failed with nonexistant method '#{sort}'"
        end
      end
      Hirb::Console.render_output(object, options)
    end
  end
end