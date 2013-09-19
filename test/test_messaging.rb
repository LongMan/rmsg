require "helper"
require "rmsg"

class RmsgClientTest < Minitest::Test
  def setup
    @client_redis = Redis.new
    @server_redis = Redis.new
    @queue = SecureRandom.uuid
  end

  def teardown
    Thread.kill(@server)
  end

  def test_simple_response
    @server = Thread.new do
      Rmsg.serve(@queue, redis: @server_redis) do |q, msg|
        "42"
      end
    end

    10.times do
      assert_equal Rmsg.send(@queue, {}, {redis: @client_redis}), "42"
    end
  end

  def test_timeout
    @server = Thread.new do
      Rmsg.serve(@queue, redis: @server_redis) do |q, msg|
        sleep 10
        "42"
      end
    end

    assert_raises Rmsg::TimeoutError do
      Rmsg.send(@queue, {}, {redis: @client_redis, timeout: 1})
    end
  end

  def test_unused_response_channels
    # 0s client sends message with timeout 1s, expire 0.5s
    # 0s server receives message, starts sleeping
    # 1s client stops waiting (stops blpop on queue)
    # 2s server ends sleeping and sends response
    # 2s response key created, will expire in 0.5s
    # 2.5s response key expired and no longer exists

    keys_count_before = @client_redis.info("keyspace")["db0"].split(",").first.split("=").last

    @server = Thread.new do
      Rmsg.serve(@queue, redis: @server_redis) do |q, msg|
        sleep 2
        "42"
      end
    end
    # 0s
    begin
      Rmsg.send(@queue, {}, {redis: @client_redis, timeout: 1, response_expire_in: 0.5})
    rescue Rmsg::TimeoutError
    end
    # 1s
    sleep 1.5
    keys_count_after = @client_redis.info("keyspace")["db0"].split(",").first.split("=").last
    assert_equal keys_count_before, keys_count_after
  end

  def test_server_durability
    i = 0
    @server = Thread.new do
      Rmsg.serve(@queue, redis: @server_redis) do |q, msg|
        i += 1
        (1/(i - 1)).to_s
      end
    end

    assert_raises Rmsg::RequestProcessingError do
      Rmsg.send(@queue, {}, {redis: @client_redis})
    end
    r = Rmsg.send(@queue, {}, {redis: @client_redis})
    assert_equal r, "1"
  end
end