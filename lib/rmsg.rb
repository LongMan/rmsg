require "yajl"

# Redis messaging
#
# Internal message format is json encoded hash:
#
# { h: header, b: body }
#
# body                - required, anything encodable to json
# header              - optional, hash with message metadata
module Rmsg

  class Rmsg::TimeoutError < StandardError
  end

  class Rmsg::RequestProcessingError < StandardError
  end

  module_function

  # Module function: Send message to queue.
  #
  # queue - queue name
  # message - something jsonable to send to queue
  # options - The Hash options (default: {}):
  #           :redis              - redis client to use instead of Redis.current
  #           :timeout            - timeout in seconds when stop to wait for answer
  #           :response_expire_in - after which period of time expire response if client crash waiting for it
  #
  # Returns server response string.
  def send(queue, message, options={})
    redis = options[:redis] || Redis.current
    timeout = options[:timeout]
    response_list = SecureRandom.uuid
    response_expire_in = options[:response_expire_in]

    redis.rpush(queue, Yajl.dump({b: message, h: { l: response_list, e: response_expire_in}}))
    q, response = redis.blpop(response_list, timeout: timeout)
    raise Rmsg::TimeoutError if q.nil? && response.nil?
    redis.del(response_list)
    response = Yajl.load(response)
    if response["h"] && response["h"]["error"]
      raise Rmsg::RequestProcessingError, response["h"]["error"]
    end
    response["b"]
  end

  # Module function: Process messages and optionally send responses.
  #
  # queue - array of string of queue names or one queue name
  # options - The Hash options used to refine the selection (default: {}):
  #           :redis              - redis client to use instead of Redis.current
  #
  # Yields the String queue name and Hash client message.
  #
  # Returns nothing.
  def serve(queues, options={})
    redis = options.delete(:redis) || Redis.current

    raise StandardError if !queues

    queues = [queues] if !queues.is_a?(Array)

    while true
      queue, msg = redis.blpop queues
      msg = Yajl.load(msg)
      respond_to = (msg["h"] || {})["l"]
      response_expire_time = (msg["h"] || {})["e"] || 60*10
      response = begin
        { b: yield(queue, msg["b"]) }
      rescue => e
        # if something went wrong responding with error
        { h: {error: e.to_s}, b: "" }
      end
      if respond_to
        redis.rpush(respond_to, Yajl.dump(response))
        redis.pexpire(respond_to, (response_expire_time*1000).to_i)
      end
    end
  end
end
