module Boson
  # This module generates views for a command by handing it to {Hirb}[http://tagaholic.me/hirb/]. Since Hirb can be customized
  # to generate any view, commands can have any views associated with them!
  #
  # === Views with Render Options
  # To pass rendering options to a Hirb helper as command options, a command has to define the options with
  # the render_options method attribute:
  #
  #   # @render_options :fields=>[:a,:b]
  #   def list(options={})
  #     [{:a=>1, :b=>2}, {:a=>10,:b=>11}]
  #   end
  #
  #   # To see that the render_options method attribute actually passes the :fields option by default:
  #   >> list '-p'   # or list '--pretend'
  #   Arguments: []
  #   Global options: {:pretend=>true, :fields=>[:a, :b]}
  #
  #   >> list
  #   +----+----+
  #   | a  | b  |
  #   +----+----+
  #   | 1  | 2  |
  #   | 10 | 11 |
  #   +----+----+
  #   2 rows in set
  #
  #   # To create a vertical table, we can pass --vertical, one of the default global render options.
  #   >> list '-V'   # or list '--vertical'
  #   *** 1. row ***
  #   a: 1
  #   b: 2
  #   ...
  #
  #   # To get the original return value don't forget --render
  #   >> list '-r'  # or list '--render'
  #   => [{:a=>1, :b=>2}, {:a=>10,:b=>11}]
  #
  # Since Boson, uses {Hirb's auto table helper}[http://tagaholic.me/hirb/doc/classes/Hirb/Helpers/AutoTable.html]
  # by default, you should read up on it if you want to use and define (Repo.config) the many options that are available
  # for this default helper. What if you want to use your own helper class? No problem. Simply pass it with the global :class option.
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
