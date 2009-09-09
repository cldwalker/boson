module Boson::Commands::IrbCore
  def self.append_features(mod)
    super if Object.const_defined?(:IRB) && IRB.const_defined?(:ExtendCommandBundle)
  end

  def self.config
    command_aliases = {"irb_jobs"=>"jobs", "irb_fg"=>"fg", "irb_kill"=>"kill", "irb_exit"=>"exit",
      "irb_context"=>"conf", 'irb_change_workspace'=>'cws', 'irb_push_workspace'=>'pushws',
      'irb_pop_workspace'=>'popws', 'irb_current_working_workspace'=>'cwws', 'irb_workspaces'=>'workspaces',
      'irb_help'=>'help', 'irb_source'=>'source'
    }
    descriptions = {:irb_push_workspace=>"Creates a workspace for given object and pushes it into the current context",
      :irb_workspaces=>"Array of workspaces for current context", :irb=>"Starts a new workspace/subsession",
      :public=>"Works same as module#public", :irb_help=>"Ri based help",
      :irb_source=>"Evals full path file line by line",
      :irb_pop_workspace=>"Pops current workspace and changes to next workspace in context",
      :irb_exit=>"Kills the current workspace/subsession", :irb_fg=>"Switch to a workspace/subsession",
      :install_alias_method=>"Aliases given method, allows lazy loading of dependent file",
      :irb_current_working_workspace=>"Prints current workspace",
      :irb_change_workspace=>"Changes current workspace to given object",
      :private=>"Works same as module#private",:irb_context=>"Displays configuration for current workspace/subsession",
      :irb_load=>"Evals file like load line by line", :irb_jobs=>"List workspaces/subsessions",
      :irb_kill=>"Kills a given workspace/subsession", :include=>"Works same as module#include",
      :irb_require=>"Evals file like require line by line"}
    commands_hash = descriptions.inject({}) {|h,(k,v)| h[k.to_s] = {:description=>v}; h}
    commands = %w{irb_load irb_require irb include private public install_alias_method}
    {:no_alias_creation=>true, :commands=>command_aliases.keys + commands, :command_aliases=>command_aliases,
      :commands_hash=>commands_hash}
  end
end