# Async architecture 2022

Educational project on asynchronous architecture.

Open `.drawio` files via <https://app.diagrams.net/>.

## How to run

Requirements:
- Ruby 3.1+
- PostgreSQL (tested with 14.2, should be 12+)
- Docker, docker-compose

```shell
# Kafka docker image with Zookeeper
# From project root, in a separate terminal
sudo docker compose up

# Authn
# From project root, in a separate terminal
cd authn
bundle
bundle exec rake dev_up
bundle exec rake seed
bundle exec rackup

# Task tracker
# From project root, in a separate terminal
cd task_tracker
bundle
bundle exec rake dev_up
bundle exec rake seed
bundle exec rackup

# Task tracker's Kafka listener
# From project root, in a separate terminal
cd task_tracker
bundle
bundle exec karafka server
```

Proceed to any desired URL:
- `http://localhost:9293` - authn, authentication and authorization
- `http://localhost:9297` - task tracker, managing tasks

Login with `admin@authn.com`:`password` for admin account.
Login with `employee1@authn.com`:`password` for employee account.
