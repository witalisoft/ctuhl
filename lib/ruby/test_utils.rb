require 'minitest'
require 'timeout'

module TestUtils

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

  def is_port_open?(ip, port)
    begin
      Timeout::timeout(1) do
        begin
          s = TCPSocket.new(ip, port)
          s.close
          return true
        rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
          return false
        end
      end
    rescue Timeout::Error
      # Ignored
    end

    false
  end

  def wait_while(timeout = 30, retry_interval = 1, &block)
    start = Time.now
    while (result = !!block.call)
      break if (Time.now - start).to_i >= timeout
      sleep(retry_interval)
    end
    !result
  end

  def http_ok?(ip, port, seconds=10)
    Timeout::timeout(seconds) do
      begin
        uri = URI("http://#{ip}:#{port}/")
        res = Net::HTTP.get_response(uri)
        return res.is_a?(Net::HTTPSuccess)
      rescue Errno::ECONNRESET, Errno::ECONNREFUSED, Errno::ECONNREFUSED, Errno::EHOSTUNREACH, EOFError
        false
      end
    end
  rescue Timeout::Error
    false
  end

end

module Minitest
  class Spec
    include TestUtils
  end
end
