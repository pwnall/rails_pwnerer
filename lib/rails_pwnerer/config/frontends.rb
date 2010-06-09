# computes the number of frontends to be used in an application

module RailsPwnage::Config
  # the number of frontends for an application
  def self.app_frontends(app_name, instance_name)
    # TODO: this is duplicated in cluster_config.rb -- pull up somewhere
    app_config = self[app_name, instance_name]
    return nil unless app_config and fixed_frontends = app_config[:frontends]

    frontends_per_core = app_config[:frontends_per_core] || 0
    detected_cores = app_config[:detected_cores] || 0
    cores_frontends = frontends_per_core * detected_cores  
    return (cores_frontends != 0) ? cores_frontends : fixed_frontends
  end
end