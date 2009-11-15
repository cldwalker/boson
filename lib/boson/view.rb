module Boson
  # Handles {Hirb}[http://tagaholic.me/hirb/]-based views, mostly for commands. Since Hirb can be customized
  # to generate any view, commands can have any views associated with them!
  #
  # === Views with Render Options
  #  TODO
  module View
    extend self

    # Enables hirb and reads a config file from the main repo's config/hirb.yml.
    def enable
      Hirb::View.enable(:config_file=>File.join(Boson.repo.config_dir, 'hirb.yml')) unless @enabled
      @enabled = true
    end

    # Renders any object via Hirb. Options are passed directly to
    # {Hirb::Console.render_output}[http://tagaholic.me/hirb/doc/classes/Hirb/Console.html#M000011].
    def render(object, options={}, return_obj=false)
      if options[:inspect] || inspected_object?(object)
        puts(object.inspect)
      else
        render_object(object, options, return_obj)
      end
    end

    #:stopdoc:
    def toggle_pager
      Hirb::View.toggle_pager
    end

    def inspected_object?(obj)
      [nil,false,true].include?(obj)
    end

    def render_object(object, options={}, return_obj=false)
      options[:class] ||= :auto_table
      render_result = Hirb::Console.render_output(object, options)
      return_obj ? object : render_result
    end
    #:startdoc:
  end
end
