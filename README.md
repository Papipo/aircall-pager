# Pager Service

## How to run the tests

You need either docker installed or ruby 3.2.2.

### Run using ruby 3.2.2

Run `bundle install`  and then `rake test`

### Run using docker

Ensure the docker daemon is running.

Run `./docker-test.sh`

## Persistence guarantees

`Pager` delegates on `repo` and expects it to handle the different scenarios provided in the specification.
This means that `repo.unhealthy` will persist the unhealthy state to the database (and return `true`) unless
there is an ongoing alert. In such case, it will persist nothing and return `false`, but Pager doesn't care
about these details.

We can't check if there is an ongoing alert and then persist because that can lead to race conditions. So we
can handle this having an `alerts` table with a unique index over the `service_id` column, for example.

Calling `repo.healthy` would delete the record inserted in the previous step.