require 'microsoft_graph'

module MicrosoftGraphClient
  class << self
    attr_accessor :client

    def configure!
      auth = MicrosoftGraph::Auth::DeviceCodeGrant.new(
        client_id: ENV["MS_CLIENT_ID"],
        client_secret: ENV["MS_CLIENT_SECRET"],
        tenant: ENV["MS_TENANT_ID"]
      )

      puts "Authorizing with Microsoft..."
      auth.get_token

      @client = MicrosoftGraph.new
      @client.auth = auth
    end
  end
end

MicrosoftGraphClient.configure!
