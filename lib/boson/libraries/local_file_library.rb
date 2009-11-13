# This class loads any local file and is most commonly used to load a local
# Bosonfile. Since this file doesn't exist inside a normal Repo, it is not indexed with any repo.
# Since file-based libraries need to be associated with a repository, Boson associates it
# with a local repository if it exists or defaults to Boson.repo. See Boson::FileLibrary
# for more info about this library.
#
# Example:
#   >> load_library 'Bosonfile'
#   => true
class Boson::LocalFileLibrary < Boson::FileLibrary
  handles {|source|
    @repo = (File.exists?(source.to_s) ? (Boson.local_repo || Boson.repo) : nil)
    !!@repo
  }

  #:stopdoc:
  def set_name(name)
    @lib_file = File.expand_path(name.to_s)
    File.basename(@lib_file).downcase
  end

  def base_module
    Boson::Commands
  end

  def library_file
    @lib_file
  end
  #:startdoc:
end