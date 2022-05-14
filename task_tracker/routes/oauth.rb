# frozen_string_literal: true

require "base64"
require "uri"
require "json"
require "net/http"

class TaskTracker
  REDIRECT_URI = "#{APP_URL}/oauth/callback".freeze
  CLIENT_ID = "TASK_TRACKER_CLIENT_ID"
  CLIENT_SECRET = CLIENT_ID

  hash_branch("oauth") do |r|
    r.is "authorize", method: "post" do
      #
      # This link redirects the user to the authorization server, to perform the authorization step.
      #
      state = Base64.urlsafe_encode64(SecureRandom.hex(32))
      session["state"] = state

      query_params = {
        "redirect_uri" => REDIRECT_URI,
        "client_id" => CLIENT_ID,
        "scope" => "profile.read",
        "state" => state,
        "access_type" => "online",
        "approval_prompt" => "auto"
      }.map { |k, v| "#{CGI.escape(k)}=#{CGI.escape(v)}" }.join("&")

      authorize_url = URI.parse(AUTHN_URL)
      authorize_url.path = "/authorize"
      authorize_url.query = query_params

      r.redirect authorize_url.to_s
    end

    r.is "callback" do
      #
      # This is the redirect uri, where the authorization server redirects to with grant information for
      # the user to generate an access token.
      #
      if r.params["error"]
        flash[:error] = "Authorization failed: #{r.params['error_description'] || r.params['error']}"
        r.redirect "/"
      end

      session_state = session.delete("state")

      if session_state
        state = request.params["state"]
        if !state || state != session_state
          flash[:error] = "state doesn't match, CSRF Attack!!!"
          r.redirect "/"
        end
      end

      code = r.params["code"]

      response = json_request(
        :post,
        "#{AUTHN_URL}/token",
        params: {
          "grant_type" => "authorization_code",
          "code" => code,
          "client_id" => CLIENT_ID,
          "client_secret" => CLIENT_SECRET,
          "redirect_uri" => REDIRECT_URI
        }
      )

      session["access_token"] = response["access_token"]
      session["refresh_token"] = response["refresh_token"]

      r.redirect "/"
    end

    r.is "logout", method: "post" do
      #
      # This endpoint uses the OAuth revoke endpoint to invalidate an access token.
      #
      access_token = session.delete("access_token")
      clear_session
      begin
        json_request(
          :post,
          "#{AUTHN_URL}/revoke",
          params: {
            "client_id" => CLIENT_ID,
            "client_secret" => CLIENT_SECRET,
            "token_type_hint" => "access_token",
            "token" => access_token
          }
        )
      rescue StandardError => e
        puts "Revocation error: #{e.message}"
      end

      flash["notice"] = "You are logged out!"
      r.redirect "/"
    end
  end

  private

  def json_request(meth, uri, headers: {}, params: {})
    uri = URI(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    case meth
    when :get
      request = Net::HTTP::Get.new(uri.request_uri)
      request["accept"] = "application/json"
      headers.each do |k, v|
        request[k] = v
      end
      response = http.request(request)
      raise "Unexpected error on token generation, #{response.body}" unless response.code.to_i == 200

      JSON.parse(response.body)
    when :post
      request = Net::HTTP::Post.new(uri.request_uri)
      request.body = JSON.dump(params)
      request["content-type"] = "application/json"
      request["accept"] = "application/json"
      headers.each do |k, v|
        request[k] = v
      end
      response = http.request(request)
      raise "Unexpected error on token generation, #{response.body}" unless response.code.to_i == 200

      JSON.parse(response.body)
    end
  end
end
