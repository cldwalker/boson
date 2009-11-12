class Boson::LocalFileLibrary < Boson::FileLibrary
  handles {|source|
    @repo = (File.exists?(source.to_s) ? (Boson.local_repo || Boson.repo) : nil)
    !!@repo
  }

  def set_name(name)
    @lib_file = File.expand_path(name.to_s)
    File.basename(@lib_file).downcase
  end

  def base_module
    Boson::Commands
  end
end