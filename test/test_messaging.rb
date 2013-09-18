require "helper"
require "rmsg"

class RmsgClientTest < Minitest::Test
  def test_simple_response
    client_redis = Redis.new
    queue = SecureRandom.uuid
    server = Thread.new do
      server_redis = Redis.new
      Rmsg.serve(queue, redis: server_redis) do |q, msg|
        "42"
      end
    end

    10.times do
      assert_equal Rmsg.send(queue, {redis: client_redis}), "42"
    end

    Thread.kill(server)
  end
end