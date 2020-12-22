require 'minitest'
require 'timeout'

module RetryUntil
  def retry_until(options = {})
    last_error = nil
    Timeout.timeout options.fetch(:timeout, 60) do
      begin
        yield
      rescue StandardError, Minitest::Assertion => e
        last_error = e
        sleep options.fetch :wait, 10
        retry
      end
    end
  rescue Timeout::Error
    raise last_error if last_error
    raise Minitest::Assertion, 'Assertion never went green'
  end
end

module Minitest
  class Spec
    include RetryUntil
  end
end