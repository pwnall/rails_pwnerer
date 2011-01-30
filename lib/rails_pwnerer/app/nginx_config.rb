# builds the nginx configuration

class RailsPwnerer::App::NginxConfig
  include RailsPwnerer::Base
    
  # writes the nginx configuration for this server
  def config_nginx(app_name, instance_name)
    app_config = RailsPwnerer::Config[app_name, instance_name]
    first_port = app_config[:port0]
    
    # Can be specified as comma-separated string or array.
    if app_config[:dns_name].respond_to? :to_str
      dns_names = app_config[:dns_name].split(',')
    else
      dns_names = app_config[:dns_name]
    end
    
    default_app_port = app_config[:ssl_key] ? 443 : 80
    app_port = app_config[:port] || default_app_port
    
    nginx_config = File.join(RailsPwnerer::Config.path_to(:nginx_configs),
                             app_name + '.' + instance_name) 
    File.open(nginx_config, 'w') do |f|
      # link to the frontends
      f << "  upstream #{app_name}_#{instance_name} {\n"
      RailsPwnerer::Config.app_frontends(app_name, instance_name).times do |instance|
        f << "    server 127.0.0.1:#{first_port + instance};\n"
      end
      f << "  }\n\n"
      
      # server configuration -- big and ugly
      f << <<NGINX_CONFIG
  server {
    listen #{app_port};
    charset utf-8;
    #{app_config[:ssl_key] ? 'ssl on;' : ''}
    #{app_config[:ssl_key] ? "ssl_certificate #{app_config[:ssl_cert]};" : ''}
    #{app_config[:ssl_key] ? "ssl_certificate_key #{app_config[:ssl_key]};" : ''}
    #{(dns_names.empty? ? '' : "server_name " + dns_names.join(' ') + ";")}
    root #{app_config[:app_path]}/public;
    client_max_body_size #{app_config[:max_request_mb]}M;
    location / {
      if (-f $request_filename) {
        expires max;
        break;
      }

      if (-f $request_filename/index.html) {
        expires max;
        rewrite (.*) $1/index.html break;
      }
      if (-f $request_filename.html) {
        expires max;
        rewrite (.*) $1.html break;
      }

      proxy_set_header X-Real-IP $remote_addr;
      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      #{app_config[:ssl_key] ? 'proxy_set_header X-Forwarded-Proto https;' : ''}
      proxy_set_header Host $host;
      proxy_redirect off;
      proxy_connect_timeout 2;
      proxy_read_timeout 86400;
      if (!-f $request_filename) {
        proxy_pass http://#{app_name}_#{instance_name};
        break;
      }
    }
  }      
NGINX_CONFIG
    end    
  end
  
  def remove_nginx_config(app_name, instance_name)
    nginx_config = File.join(RailsPwnerer::Config.path_to(:nginx_configs), app_name + '.' + instance_name) 
    File.delete nginx_config if File.exists? nginx_config    
  end
  
  # removes the default configuration stub (so nginx doesn't stumble upon it)
  def remove_nginx_stub
    stub_file = File.join(RailsPwnerer::Config.path_to(:nginx_configs), 'default')
    File.delete stub_file  if File.exists?(stub_file)
  end
  
  def setup(app_name, instance_name)
    config_nginx app_name, instance_name
    remove_nginx_stub
  end
  
  def update(app_name, instance_name)
    config_nginx app_name, instance_name
    control_boot_script('nginx', :reload)
  end
  
  def remove(app_name, instance_name)
    remove_nginx_config app_name, instance_name
    control_boot_script('nginx', :reload)
  end
  
  def control_all(action)
    case action
    when :start
      control_boot_script('nginx', :reload)
      control_boot_script('nginx', :start)
    when :stop
      control_boot_script('nginx', :stop)
    when :reload
      control_boot_script('nginx', :reload)
    end
  end
end
