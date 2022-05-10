# frozen_string_literal: true

require_relative "models"

require "base64"
require "uri"
require "json"
require "net/http"
require "roda"
require "tilt/sass"

class TaskTracker < Roda
  AUTHN_URL = "http://localhost:9293"
  TASK_TRACKER_URL = "http://localhost:9297"
  REDIRECT_URI = "#{TASK_TRACKER_URL}/callback".freeze
  CLIENT_ID = "TASK_TRACKER_CLIENT_ID"
  CLIENT_SECRET = CLIENT_ID

  opts[:check_dynamic_arity] = false
  opts[:check_arity] = :warn

  plugin :default_headers,
         "Content-Type" => "text/html",
         # 'Strict-Transport-Security'=>'max-age=16070400;', # Uncomment if only allowing https:// access
         "X-Frame-Options" => "deny",
         "X-Content-Type-Options" => "nosniff",
         "X-XSS-Protection" => "1; mode=block"

  plugin :content_security_policy do |csp|
    csp.default_src :none
    csp.style_src :self, "https://cdn.jsdelivr.net"
    csp.form_action :self, AUTHN_URL
    csp.script_src :self
    csp.connect_src :self
    csp.base_uri :none
    csp.frame_ancestors :none
  end

  plugin :route_csrf
  plugin :flash
  plugin :assets, css: "app.scss", css_opts: { style: :compressed, cache: false }, timestamp_paths: true
  plugin :render, escape: true, layout: "./layout"
  plugin :public

  logger = if ENV["RACK_ENV"] == "test"
             Class.new { def write(_) end }.new
           else
             $stderr
           end
  plugin :common_logger, logger

  plugin :not_found do
    @page_title = "File Not Found"
    view(content: "")
  end

  if ENV["RACK_ENV"] == "development"
    plugin :exception_page
    class RodaRequest
      def assets
        exception_page_assets
        super
      end
    end
  end

  plugin :error_handler do |e|
    case e
    when Roda::RodaPlugins::RouteCsrf::InvalidToken
      @page_title = "Invalid Security Token"
      response.status = 400
      view(content: "<p>An invalid security token was submitted with this "\
                    "request, and this request could not be processed.</p>")
    else
      $stderr.print "#{e.class}: #{e.message}\n"
      warn e.backtrace
      next exception_page(e, assets: true) if ENV["RACK_ENV"] == "development"

      @page_title = "Internal Server Error"
      view(content: "")
    end
  end

  plugin :sessions,
         key: "_TaskTracker.session",
         # cookie_options: {secure: ENV['RACK_ENV'] != 'test'}, # Uncomment if only allowing https:// access
         secret: ENV.send((ENV["RACK_ENV"] == "development" ? :[] : :delete), "TASK_TRACKER_SESSION_SECRET")

  route do |r|
    r.public
    r.assets
    check_csrf!

    #
    # Authentication
    #
    @logged_in = !session["access_token"].nil?
    if (token = session["access_token"])
      session["account"] ||= json_request(
        :get,
        "#{AUTHN_URL}/accounts/current",
        headers: { "authorization" => "Bearer #{token}" }
      )
      @current_account = Account.first(public_id: session["account"]["public_id"])
      if @current_account.nil?
        clear_session
        @logged_in = false
      end
    end

    r.root do
      if @logged_in
        r.redirect "/tasks"
      else
        view inline: "You are not authorized"
      end
    end

    #
    # CRUD
    #

    r.on "tasks" do
      @page_title = "Tasks"

      r.is do
        r.get do
          view "index", locals: { tasks: Task.eager(:account).all }
        end
        r.post do
          random_employee_public_id = Account.random_employees.get(:public_id)
          task = Task.create(assignee_public_id: random_employee_public_id, description: "Lorem ipsum")
          Producer.call(
            {
              name: "TaskCreated",
              data: {
                public_id: task.public_id,
                actor_public_id: @current_account.public_id,
                description: task.description,
                assignee_public_id: task.assignee_public_id,
                status: task.status
              }
            },
            topic: "tasks-stream"
          )
          Producer.call(
            {
              name: "TaskAdded",
              data: {
                public_id: task.public_id,
                actor_public_id: @current_account.public_id,
                assignee_public_id: task.assignee_public_id
              }
            },
            topic: "tasks"
          )
          r.redirect "/tasks"
        end
      end

      r.is "my" do
        view "index", locals: { tasks: @current_account.tasks }
      end

      r.is Integer, "close" do |id|
        task = Task.first(id:)
        if can_close?(task)
          task.close
          Producer.call(
            {
              name: "TaskStatusUpdated",
              data: {
                actor_public_id: @current_account.public_id,
                public_id: task.public_id,
                status: task.status
              }
            },
            topic: "tasks-stream"
          )
          Producer.call(
            {
              name: "TaskClosed",
              data: {
                actor_public_id: @current_account.public_id,
                public_id: task.public_id
              }
            },
            topic: "tasks"
          )
        end
        r.redirect "/tasks"
      end

      r.is "shuffle", method: "post" do
        if can_shuffle?
          shuffled_tasks = Task.shuffle
          shuffled_tasks.each do |task|
            Producer.call(
              {
                name: "TaskStatusUpdated",
                data: {
                  actor_public_id: @current_account.public_id,
                  public_id: task[:public_id],
                  assignee_public_id: task[:assignee_public_id]
                }
              },
              topic: "tasks-stream"
            )
          end
          Producer.call(
            {
              name: "TasksShuffled",
              data: {
                actor_public_id: @current_account.public_id,
                public_ids: shuffled_tasks.map { _1[:public_id] }
              }
            },
            topic: "tasks"
          )
        else
          flash[:error] = "Not authorized"
        end
        r.redirect "/tasks"
      end
    end

    #
    # OAuth
    #

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
        logger.warn "Revocation error: #{e.message}"
      end

      flash["notice"] = "You are logged out!"
      r.redirect "/"
    end
  end

  private

  def can_close?(task)
    task.status == "open" && task.assignee_public_id == @current_account.public_id
  end

  def can_shuffle?
    @current_account.role == "manager" || @current_account.role == "admin"
  end

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
