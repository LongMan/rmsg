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
    @server = Thread.new do
      Rmsg.serve(@queue, redis: @server_redis) do |q, msg|
        sleep 2
        "42"
      end
    end

    begin
      Rmsg.send(@queue, {}, {redis: @client_redis, timeout: 1, response_expire_in: 2})
    rescue Rmsg::TimeoutError
    end
    sleep 2
    keys_count_1 = @client_redis.info("keyspace")["db0"].split(",").first.split("=").last.to_i
    sleep 1
    keys_count_2 = @client_redis.info("keyspace")["db0"].split(",").first.split("=").last.to_i
    assert_equal keys_count_1 - 1, keys_count_2
  end

  def test_server_durability
    i = 0
    @server = Thread.new do
      Rmsg.serve(@queue, redis: @server_redis) do |q, msg|
        i += 1
        (1/(i - 1)).to_s
      end
    end

    r = Rmsg.send(@queue, {}, {redis: @client_redis})
    r = Rmsg.send(@queue, {}, {redis: @client_redis})
    assert_equal r, "1"
  end


















end