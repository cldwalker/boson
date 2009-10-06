# Module under which most library modules are evaluated.
module Boson::Commands
  # Used for defining namespaces.
  module Namespace; end
end
require 'boson/commands/core'
require 'boson/commands/web_core'
require 'boson/commands/irb_core'