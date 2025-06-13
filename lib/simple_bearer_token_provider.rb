class SimpleBearerTokenProvider
  def initialize(token)
    @token = token
  end

  def authenticate_request(request)
    Fiber.new do
      request.headers.add('Authorization', "Bearer #{@token}")
    end
  end
end
