require 'net/http'
require 'uri'
require 'json'
require 'oauth2'

require 'microsoft_graph'
require 'microsoft_graph_core'
require 'microsoft_kiota_authentication_oauth'
require 'microsoft_kiota_abstractions'

require_relative './simple_bearer_token_provider'

class MsGraph
  TOKEN_FILE = Rails.root.join("tmp/ms_graph_token.json")

  def initialize
    @client_id     = ENV.fetch("MS_CLIENT_ID")
    @client_secret = ENV.fetch("MS_CLIENT_SECRET")
    @tenant        = ENV.fetch("MS_TENANT_ID", "common")
    @scopes        = "offline_access Calendars.Read"

    @oauth_client = OAuth2::Client.new(
      @client_id,
      @client_secret,
      site: "https://login.microsoftonline.com/#{@tenant}",
      token_url: "/oauth2/v2.0/token"
    )
  end

  def client
    token = load_or_authorize_token
    auth_provider = SimpleBearerTokenProvider.new(token.token)
    adapter = MicrosoftGraph::GraphRequestAdapter.new(auth_provider)
    MicrosoftGraph::GraphServiceClient.new(adapter)
  end

  private

  def load_or_authorize_token
    if File.exist?(TOKEN_FILE)
      saved = JSON.parse(File.read(TOKEN_FILE))
      token = OAuth2::AccessToken.from_hash(@oauth_client, saved)
      return token.refresh! if token.expired?
      token
    else
      start_device_code_flow
    end
  end

  def start_device_code_flow
    uri = URI("https://login.microsoftonline.com/#{@tenant}/oauth2/v2.0/devicecode")
    res = Net::HTTP.post_form(uri, {
      'client_id' => @client_id,
      'scope'     => @scopes
    })

    unless res.is_a?(Net::HTTPSuccess)
      puts "Microsoft returned #{res.code} #{res.message}"
      puts res.body
      raise "Device code request failed"
    end

    data = JSON.parse(res.body)
    puts "\n🔐 Visit #{data['verification_uri']} and enter this code: #{data['user_code']}\n\n"

    poll_for_token(data)
  end

  def poll_for_token(data)
    interval    = data['interval'] || 5
    expires_at  = Time.now + data['expires_in']
    token_uri   = URI("https://login.microsoftonline.com/#{@tenant}/oauth2/v2.0/token")

    puts "Waiting for you to authorize the app... (expires in #{data['expires_in']}s)"
    attempts = 0

    while Time.now < expires_at
      sleep interval
      attempts += 1
      puts "Polling for token... (attempt #{attempts})"

      response = Net::HTTP.post_form(token_uri, {
        grant_type:  "urn:ietf:params:oauth:grant-type:device_code",
        client_id:   @client_id,
        device_code: data['device_code']
      })

      body   = response.body.to_s.strip
      parsed = body.empty? ? {} : JSON.parse(body)

      if response.is_a?(Net::HTTPSuccess)
        token = OAuth2::AccessToken.from_hash(@oauth_client, parsed)
        store_token(token)
        puts "✅ Authorization complete!"
        return token
      else
        error = parsed["error"]

        case error
        when "authorization_pending"
          next
        when "slow_down"
          interval += 5
          puts "Microsoft says slow down. Increasing polling interval to #{interval}s."
          next
        when "authorization_declined"
          raise "❌ You declined the authorization."
        when "expired_token"
          raise "❌ Device code expired. Please restart the process."
        else
          puts "❌ Token exchange failed: #{parsed}"
          raise "Token request failed with: #{error || 'unknown error'}"
        end
      end
    end

    raise "❌ Authorization timed out after #{data['expires_in']} seconds."
  end

  def store_token(token)
    File.write(TOKEN_FILE, token.to_hash.to_json)
  end
end
