# sets up the user permissions on the dir skeleton

require 'fileutils'

class RailsPwnage::Scaffolds::DirPermissions
  include RailsPwnage::Base

  # runner
  def run
    pwnerer_uid = uid_for_username(RailsPwnage::Config[:host][:pwnerer_user])
    Dir.chdir('/') do
      [:config,  :apps, :backups].map { |k| RailsPwnage::Config.path_to k }.each do |path|
        FileUtils.mkpath path
        File.chown(pwnerer_uid, nil, path)
      end
    end
  end

  # standalone runner
  def self.go
    self.new.run
  end
end
