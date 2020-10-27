$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'virtfs'
require 'virtfs-nativefs-thick'
require 'virtfs-iso9660'
require 'factory_girl'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end

  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FactoryBot.find_definitions
  end

end

def reset_context
  VirtFS.context_manager.reset_all
end
