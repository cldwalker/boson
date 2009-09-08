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
    commands = %w{irb_load irb_require irb include private public install_alias_method}
    {:no_alias_creation=>true, :commands=>command_aliases.keys + commands, :command_aliases=>command_aliases}
  end
end