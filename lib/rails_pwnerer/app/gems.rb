# sets up the application gems

class RailsPwnerer::App::Gems
  include RailsPwnerer::Base

  def update(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]

    Dir.chdir app_config[:app_path] do
      # Phase 1: app-directed install
      if !File.exist?('Gemfile') && app_config[:gems]
        # Can be specified as comma-separated string or array.
        if app_config[:gems].respond_to? :to_str
          install_gems = app_config[:gems].split(',')
        else
          install_gems = app_config[:gems]
        end
        install_gems.each do |gem_name|
          begin
            install_gem gem_name unless gem_exists? gem_name
          rescue Exception
          end
        end
      end

      # Phase 2: bundler / rails install
      # Install the gems needed by the app.
      if File.exist? 'Gemfile'
        unless /^\s+gem\s+['"]thin['"]/ =~ File.read('Gemfile')
          File.open('Gemfile', 'a') { |f| f.write "\ngem 'thin'\n"}
        end
        Kernel.system "bundle install --without development test"
      else
        Kernel.system "rake gems:install RAILS_ENV=production"
      end
    end
  end

  def manage(app_name, instance_name, action)
    # Called when an app is rolled back, to get the old gems reinstalled,
    # if necessary.
    update(app_name, instance_name)
  end

  def setup(app_name, instance_name)
    update(app_name, instance_name)
  end
end
