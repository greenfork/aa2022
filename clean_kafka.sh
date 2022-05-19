#!/bin/env bash

topics=(
    account-access-control
    accounts-stream
    task-lifecycle
    tasks-stream
)

for topic in ${topics[*]}; do
    docker compose exec broker kafka-topics --zookeeper zookeeper:2181 --delete --topic $topic
done
