module Boson
  # This module passes an original command's return value through methods/commands specified as pipe options. Pipe options
  # are processed in this order:
  # * A :query option searches an array of objects or hashes using Pipes.query_pipe.
  # * A :sort option sorts an array of objects or hashes using Pipes.sort_pipe.
  # * A :reverse_sort pipe option reverses an array.
  # * A :pipes option takes an array of commands that modify the return value using Pipes.pipes_pipe.
  # * All user-defined pipe options (:pipe_options key in Repo.config) are processed in random order.
  #
  # Some points:
  # * User-defined pipes call a command (the option's name by default). It's the user's responsibility to have this
  #   command loaded when used. The easiest way to do this is by adding the pipe command's library to :defaults in main config.
  # * By default, pipe commands do not modify the value their given. This means you can activate multiple pipes using
  #   a method's original return value.
  # * A pipe command expects a command's return value as its first argument. If the pipe option takes an argument, it's passed
  #   on as a second argument.
  # * When piping occurs in relation to rendering depends on the Hirb view. With the default Hirb view, piping occurs
  #   occurs in the middle of the rendering, after Hirb has converted the return value into an array of hashes.
  #   If using a custom Hirb view, piping occurs before rendering.
  # * What the pipe command should expect as a return value depends on the type of command. If it's a command rendered with hirb's
  #   tables, the return value is a an array of hashes. For everything else, it's the method's original return value.
  #
  # === User Pipes
  # User pipes have the following attributes which alter their behavior:
  # [*:pipe*] Pipe command the pipe executes when called. Default is the pipe's name.
  # [*:env*] Boolean which enables passing an additional hash to the pipe command. This hash contains information from the first
  #          command's input with the following keys: :args (command's arguments), :options (command's options),
  #          :global_options (command's global options) and :config (a command's configuration hash). Default is false.
  # [*:filter*] Boolean which has the pipe command modify the original command's output with the value it returns. Default is false.
  # [*:no_render*] Boolean to turn off auto-rendering of the original command's final output. Only applicable to :filter enabled
  #                pipes. Default is false.
  # [*:solo*] Boolean to indicate this pipe can't run with other user pipes or pipes from :pipes option.
  #           If a user calls multiple solo pipes, only the first one detected is called.
  #
  # === User Pipes Example
  # Let's say you want to have two commands, browser and copy, you want to make available as pipe options:
  #    # Opens url in browser. This command already ships with Boson.
  #    def browser(url)
  #      system('open', url)
  #    end
  #
  #    # Copy to clipboard
  #    def copy(str)
  #      IO.popen('pbcopy', 'w+') {|clipboard| clipboard.write(str)}
  #    end
  #
  # To configure them, drop the following config in ~/.boson/config/boson.yml:
  #   :pipe_options:
  #     :browser:
  #       :type: :boolean
  #       :desc: Open in browser
  #     :copy:
  #       :type: :boolean
  #       :desc: Copy to clipboard
  #
  # Now for any command that returns a url string, these pipe options can be turned on to execute the url.
  #
  # Some examples of these options using commands from {my libraries}[http://github.com/cldwalker/irbfiles]:
  #    # Creates a gist and then opens url in browser and copies it.
  #    $ cat some_file | boson gist -bC        # or cat some_file | boson gist --browser --copy
  #
  #    # Generates rdoc in current directory and then opens it in browser
  #    irb>> rdoc '-b'    # or rdoc '--browser'
  module Pipe
    extend self

    # Process pipes for Scientist
    def scientist_process(object, global_opt, env={})
      @env = env
      [:query, :sort, :reverse_sort].each {|e| global_opt.delete(e) } unless object.is_a?(Array)
      process_pipes(object, global_opt)
    end

    # Main method which processes all pipe commands, both default and user-defined ones.
    def process_pipes(obj, options)
      internal_pipes(options).each {|pipe|
        obj = Pipes.send("#{pipe}_pipe", obj, options[pipe]) if options[pipe]
      }
      process_user_pipes(obj, options)
    end

    # A hash that defines user pipes in the same way as the :pipe_options key in Repo.config.
    # This method should be called when a pipe's library is loading.
    def add_pipes(hash)
      pipe_options.merge! setup_pipes(hash)
    end

    #:stopdoc:
    def internal_pipes(global_opt)
      internals = [:query, :sort, :reverse_sort, :pipes]
      internals.delete(:pipes) if pipes_to_process(global_opt).any? {|e| pipe(e)[:solo] }
      internals
    end

    def pipe_options
      @pipe_options ||= setup_pipes(Boson.repo.config[:pipe_options] || {})
    end

    def setup_pipes(hash)
      hash.each {|k,v| v[:pipe] ||= k }
    end

    def pipe(key)
      pipe_options[key] || {}
    end

    # global_opt can come from Hirb callback or Scientist
    def process_user_pipes(result, global_opt)
      pipes_to_process(global_opt).each {|e|
        args = [pipe(e)[:pipe], result]
        args << global_opt[e] unless pipe(e)[:type] == :boolean
        args << get_env(e, global_opt) if pipe(e)[:env]
        pipe_result = Boson.invoke(*args)
        result = pipe_result if pipe(e)[:filter]
      }
      result
    end

    def get_env(key, global_opt)
      { :global_options=>global_opt.merge(:delete_callbacks=>[:z_boson_pipes]),
        :config=>(@env[:config].dup[key] || {}),
        :args=>@env[:args],
        :options=>@env[:options] || {}
      }
    end

    def any_no_render_pipes?(global_opt)
      !(pipes = pipes_to_process(global_opt)).empty? &&
        pipes.any? {|e| pipe(e)[:no_render] }
    end

    def pipes_to_process(global_opt)
      pipes = (global_opt.keys & pipe_options.keys)
      (solo_pipe = pipes.find {|e| pipe(e)[:solo] }) ? [solo_pipe] : pipes
    end
    #:startdoc:

    # Callbacks used by Hirb::Helpers::Table to search,sort and run custom pipe commands on arrays of hashes.
    module TableCallbacks
      # Processes boson's pipes
      def z_boson_pipes_callback(obj, options)
        Pipe.process_pipes(obj, options)
      end
    end
  end
end
Hirb::Helpers::Table.send :include, Boson::Pipe::TableCallbacks