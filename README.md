# Async architecture 2022

Educational project on asynchronous architecture.

Open `.drawio` files via <https://app.diagrams.net/>.

## How to run

Requirements:
- Ruby 3.1+
- PostgreSQL (tested with 14.2, should be 12+)
- Docker, docker-compose

Setup:
```shell
# Authn
# From project root, in a separate terminal
cd authn
bundle
bundle exec rake dev_up
bundle exec rake seed

# Task tracker
# From project root, in a separate terminal
cd task_tracker
bundle
bundle exec rake dev_up
bundle exec rake seed

# Billing
# From project root, in a separate terminal
cd billing
bundle
bundle exec rake dev_up
bundle exec rake seed

# Analytics
# From project root, in a separate terminal
cd analytics
bundle
bundle exec rake dev_up
bundle exec rake seed
```

Run:
```shell
# In a separate terminal:
sudo docker compose up

# In a separate terminal:
bin/start
```

Proceed to any desired URL:
- `http://localhost:9293` - authn, authentication and authorization
- `http://localhost:9294` - task tracker, managing tasks
- `http://localhost:9295` - billing
- `http://localhost:9296` - analytics

Login with `admin@authn.com`:`password` for admin account.
Login with `employee1@authn.com`:`password` for employee account.
