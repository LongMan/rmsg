require "yajl"

module Rmsg
  module_function
  def send(queue, options={})
    redis = options.delete(:redis) || Redis.current
    response_list = SecureRandom.uuid
    puts "sending #{options.inspect} to #{queue} via #{redis.inspect}"
    redis.rpush(queue, Yajl.dump(options.merge(respond_to: response_list)))
    q, response = redis.blpop(response_list)
    redis.del(response_list)
    response
  end

  def serve(queues, options={})
    puts "server starting"
    redis = options.delete(:redis) || Redis.current

    raise StandardError if !queues

    queues = [queues] if !queues.is_a?(Array)
    puts "serving #{queues.inspect} with #{redis.inspect}"

    while true
      puts "waiting for message"
      queue, message = redis.blpop queues
      message = Yajl.load(message)
      puts "got #{message}"
      response = yield(queue, message)
      puts "response is #{response}"
      redis.rpush(message["respond_to"], response)
      puts "responded to #{message["respond_to"]}"
    end
  end
end
