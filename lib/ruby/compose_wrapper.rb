require 'docker'
require 'docker/compose'

# Simple wrapper for compose files
class ComposeWrapper < Docker::Compose::Session

  def initialize(file, dir = '.')
    super(dir: dir, file: file)
  end

  def docker_host

    if ENV['GITLAB_DOCKER_HOST']
      return ENV['GITLAB_DOCKER_HOST']
    end

    if File.exist?('/.dockerenv')
      # assume default docker bridge network, this is good enough
      '172.17.0.1'
    else
      URI(Docker.url).host || 'localhost'
    end
  end

  def address(service, port, protocol: 'tcp', index: 1)
    mapped_port = port(
      service, port,
      protocol: protocol,
      index: index
    )
    _, port = mapped_port.split(':')
    [docker_host, Integer(port)]
  end

  def container_id(service_name, index: 1)
    ps(service_name)[index - 1].id
  end

  def extract_ip(service_name, index: 1)
    `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' #{container_id(service_name, index: index)}`.strip
  end

  def exec(service_name, command, index: 1)
    `docker exec #{container_id(service_name, index: index)} #{command}`.strip
  end

  def image(service)
    ps(service).first.image
  end

  def dump_logs
    run!('logs', '--tail=all')
  end

  def logs(service)
    run!('logs', service)
  end

  def down
    run!('down', '-v')
  end

  def force_shutdown
    run!('rm', '--force', '--stop', '-v')
  end
end
