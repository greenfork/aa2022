# frozen_string_literal: true

require_relative "models"

require "roda"
require "tilt/sass"

class Authn < Roda
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
    csp.form_action "*"
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
  plugin :json

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
         key: "_Authn.session",
         # cookie_options: {secure: ENV['RACK_ENV'] != 'test'}, # Uncomment if only allowing https:// access
         secret: ENV.send((ENV["RACK_ENV"] == "development" ? :[] : :delete), "AUTHN_SESSION_SECRET")

  plugin :rodauth, json: true do
    enable :login, :logout, :create_account, :oauth
    account_password_hash_column :password_hash
    login_return_to_requested_location? true
    oauth_application_scopes %w[profile.read]
    oauth_valid_uri_schemes %w[http https]

    after_create_account do
      acc = Account.first(id: account[:id])
      Producer.call(
        {
          name: "AccountCreated",
          data: {
            public_id: acc[:public_id],
            email: acc[:email],
            full_name: acc[:full_name],
            role: acc[:role]
          }
        },
        topic: "accounts-stream"
      )
    end
  end

  route do |r|
    r.public
    r.assets
    r.rodauth

    r.root do
      r.redirect "accounts"
    end

    #
    # Endpoint to respond to all other services for SSO.
    #

    r.is "accounts/current" do
      rodauth.require_oauth_authorization("profile.read")
      acc = rodauth.account_from_session
      {
        public_id: acc[:public_id],
        email: acc[:email],
        full_name: acc[:full_name],
        role: acc[:role]
      }
    end

    rodauth.require_authentication
    rodauth.oauth_applications
    rodauth.oauth_tokens
    check_csrf!

    #
    # CRUD for accounts
    #

    r.on "accounts" do
      @page_title = "Accounts"

      r.is do
        view "index", locals: { accounts: Account.all }
      end

      r.on Integer do |id|
        @page_title = "Account ##{id}"

        r.is do
          r.get do
            view "edit", locals: { account: Account.first(id:) }
          end
          r.post do
            acc = Account.first(id:)
            new_role = acc.role == r.params["role"] ? nil : r.params["role"]
            acc.update(full_name: r.params["name"], role: r.params["role"])
            Producer.call(
              {
                name: "AccountUpdated",
                data: {
                  public_id: acc[:public_id],
                  email: acc[:email],
                  full_name: acc[:full_name]
                }
              },
              topic: "accounts-stream"
            )
            if new_role
              Producer.call(
                {
                  name: "AccountRoleChanged",
                  data: { public_id: acc[:public_id], role: new_role }
                },
                topic: "account-access-control"
              )
            end
            r.redirect "/accounts"
          end
        end

        r.is "delete", method: "post" do
          acc = Account.first(id:)
          acc.destroy
          Producer.call(
            {
              name: "AccountDeleted",
              data: { public_id: acc.public_id }
            },
            topic: "accounts-stream"
          )
          r.redirect "/accounts"
        end
      end
    end
  end
end
