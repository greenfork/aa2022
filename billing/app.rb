# frozen_string_literal: true

require_relative "models"

require "roda"
require "tilt/sass"

class Billing < Roda
  APP_URL = "http://localhost:9295"
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
  plugin :view_options
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
         key: "_Billing.session",
         # cookie_options: {secure: ENV['RACK_ENV'] != 'test'}, # Uncomment if only allowing https:// access
         secret: ENV.send((ENV["RACK_ENV"] == "development" ? :[] : :delete), "BILLING_SESSION_SECRET")

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
        r.redirect "/billing"
      else
        view inline: "You are not authorized"
      end
    end

    #
    # OAuth
    #

    r.hash_branches

    r.redirect "/" unless @logged_in

    r.on "billing" do
      r.is do
        r.redirect @current_account.id unless admin_access?
        view "index", locals: { employees: Account.employees }
      end

      r.is Integer do |account_id|
        r.redirect @current_account.id if !admin_access? && @current_account.id != account_id
        account = Account.first(id: account_id)
        @page_title = account.full_name.empty? ? account.public_id : account.full_name
        view "show", locals: {
          transactions: Transaction.today.where(account_public_id: account.public_id).order(:performed_at),
          account:
        }
      end
    end
  end

  def admin_access?
    @current_account.role == "admin" || @current_account.role == "accountant"
  end
end
