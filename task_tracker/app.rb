# frozen_string_literal: true

require_relative "models"

require "roda"
require "tilt/sass"

class TaskTracker < Roda
  APP_URL = "http://localhost:9294"
  AUTHN_URL = "http://localhost:9293"

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
  plugin :hash_routes

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

  Unreloader.require( # rubocop:disable Lint/EmptyBlock
    "routes",
    delete_hook: proc { |f| hash_branch(File.basename(f).delete_suffix(".rb")) }
  ) {}

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
    # OAuth
    #

    r.hash_branches

    r.redirect "/" unless @logged_in

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
          task = Task.add(assignee_public_id: random_employee_public_id, description: "[UBERPOP-42] Lorem ipsum")
          Producer.call(
            {
              event_name: "TaskCreated",
              data: {
                public_id: task.public_id,
                actor_public_id: @current_account.public_id,
                description: task.description,
                jira_id: task.jira_id,
                assignee_public_id: task.assignee_public_id,
                status: task.status
              }
            },
            topic: "tasks-stream"
          )
          Producer.call(
            {
              event_name: "TaskAdded",
              data: {
                public_id: task.public_id,
                actor_public_id: @current_account.public_id,
                assignee_public_id: task.assignee_public_id
              }
            },
            topic: "task-lifecycle"
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
              event_name: "TaskClosed",
              data: {
                actor_public_id: @current_account.public_id,
                public_id: task.public_id
              }
            },
            topic: "task-lifecycle"
          )
        end
        r.redirect "/tasks"
      end

      r.is "shuffle", method: "post" do
        if can_shuffle?
          shuffled_tasks = Task.shuffle_all_open
          Producer.call(
            shuffled_tasks.map do |task|
              {
                event_name: "TaskShuffled",
                data: {
                  actor_public_id: @current_account.public_id,
                  public_id: task[:public_id],
                  assignee_public_id: task[:assignee_public_id]
                }
              }
            end,
            topic: "task-lifecycle"
          )
        else
          flash[:error] = "Not authorized"
        end
        r.redirect "/tasks"
      end
    end
  end

  private

  def can_close?(task)
    task.status == "open" && task.assignee_public_id == @current_account.public_id
  end

  def can_shuffle?
    @current_account.role == "manager" || @current_account.role == "admin"
  end
end
