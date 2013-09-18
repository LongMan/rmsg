require "yajl"

# Redis messaging
#
# Internal message format stored in redis is json encoded hash:
#
# { m: message, r: { l: response_list, e: response_expires_in } }
#
# message             - anything encodable to json
# response_list       - on which redis list client awaits for response
# response_expires_in - ttl in seconds for response_list
module Rmsg

  class Rmsg::TimeoutError < StandardError
  end

  module_function

  # Module function: Send message to queue.
  #
  # queue - queue name
  # message - something jsonable to send to queue
  # options - The Hash options used to refine the selection (default: {}):
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

    redis.rpush(queue, Yajl.dump({m: message, r: { l: response_list, e: response_expire_in}}))
    q, response = redis.blpop(response_list, timeout: timeout)
    raise Rmsg::TimeoutError if q.nil? && response.nil?
    redis.del(response_list)
    response
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
      queue, payload = redis.blpop queues
      payload = Yajl.load(payload)
      message = payload["m"]
      respond_to = (payload["r"] || {})["l"]
      response_expire_time = (payload["r"] || {})["e"] || 60*10
      response = begin
        yield(queue, message)
      rescue => e
        Yajl.dump({error: e.to_s})
      end
      if respond_to
        redis.rpush(respond_to, response)
        redis.expire(respond_to, response_expire_time)
      end
    end
  end
end
