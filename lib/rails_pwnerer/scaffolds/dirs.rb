# sets up the required directory structure

require 'fileutils'

class RailsPwnage::Scaffolds::Dirs
  include RailsPwnage::Base

  # runner
  def run
    Dir.chdir('/') do
      [:config,  :apps, :backups].map { |k| RailsPwnage::Config.path_to k }.each do |path|
        FileUtils.mkpath path
      end
    end
  end

  # standalone runner
  def self.go
    self.new.run
  end
end
