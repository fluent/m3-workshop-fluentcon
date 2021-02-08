#!/usr/bin/env bash

set -e

# Retries a command a configurable number of times with backoff.
#
# The retry count is given by ATTEMPTS (default 3), the initial backoff
# timeout is given by TIMEOUT in seconds (default 1.)
#
# Successive backoffs double the timeout.
# adapted from: https://stackoverflow.com/questions/8350942/how-to-re-run-the-curl-command-automatically-when-the-error-occurs/8351489#8351489
function retry_with_backoff {
  local max_attempts=${ATTEMPTS-5}
  local timeout=${TIMEOUT-1}
  local max_timeout=${MAX_TIMEOUT}
  local attempt=1
  local exitCode=0

  while (( attempt <= max_attempts ))
  do
    set +e
    eval "$@"
    exitCode=$?
    set -e
    if [[ "$exitCode" == 0 ]]; then
      return 0
    fi

    if [[ attempt -eq max_attempts ]]; then
      break
    fi

    echo "Retrying in $timeout.." 1>&2
    sleep "$timeout"
    attempt=$(( attempt + 1 ))
    timeout=$(( timeout * 2 ))
    if [[ $max_timeout != "" ]]; then
      if [[ $timeout -gt $max_timeout ]]; then
        timeout=$max_timeout
      fi
    fi
  done

  if [[ $exitCode != 0 ]]
  then
    echo "FAILURE: returning exit code '$exitCode': You've failed me for the last time! ($*)" 1>&2
  fi

  return $exitCode
}

# Variables
COORDINATOR_API_HOST=${COORDINATOR_API_HOST:-"m3coordinator01:7201"}
M3DB_SEED_HOST=${M3DB_SEED_HOST:-"m3db_seed:9002"}


# M3 cluster provisioning sequence
ATTEMPTS=50 MAX_TIMEOUT=4 TIMEOUT=1 retry_with_backoff \
  'curl -sSf ${COORDINATOR_API_HOST}/health'

echo "Initializing namespaces"
curl -sSf -X POST ${COORDINATOR_API_HOST}/api/v1/services/m3db/namespace -d '{
  "name": "default",
  "options": {
    "bootstrapEnabled": true,
    "flushEnabled": true,
    "writesToCommitLog": true,
    "cleanupEnabled": true,
    "snapshotEnabled": true,
    "repairEnabled": false,
    "retentionOptions": {
      "retentionPeriodDuration": "48h",
      "blockSizeDuration": "2h",
      "bufferFutureDuration": "10m",
      "bufferPastDuration": "10m",
      "blockDataExpiry": true,
      "blockDataExpiryAfterNotAccessPeriodDuration": "5m"
    },
    "indexOptions": {
      "enabled": true,
      "blockSizeDuration": "2h"
    }
  }
}'
echo "Done initializing namespaces"

echo "Validating namespace"
[ "$(curl -sSf ${COORDINATOR_API_HOST}/api/v1/services/m3db/namespace | jq .registry.namespaces.default.indexOptions.enabled)" == true ]
echo "Done validating namespace"

echo "Waiting for namespaces to be ready"
[ $(curl -sSf -X POST ${COORDINATOR_API_HOST}/api/v1/services/m3db/namespace/ready -d "{ \"name\": \"default\", \"force\": true }" | grep -c true) -eq 1 ]
echo "Done waiting for namespaces to be ready"

echo "Initializing topology"
if [[ "$USE_MULTI_DB_NODES" = true ]] ; then
    curl -sSf -X POST ${COORDINATOR_API_HOST}/api/v1/services/m3db/placement/init -d '{
        "num_shards": 64,
        "replication_factor": 3,
        "instances": [
            {
                "id": "m3db_seed",
                "isolation_group": "rack-a",
                "zone": "embedded",
                "weight": 1024,
                "endpoint": "m3db_seed:9000",
                "hostname": "m3db_seed",
                "port": 9000
            },
            {
                "id": "m3db_data01",
                "isolation_group": "rack-b",
                "zone": "embedded",
                "weight": 1024,
                "endpoint": "m3db_data01:9000",
                "hostname": "m3db_data01",
                "port": 9000
            },
            {
                "id": "m3db_data02",
                "isolation_group": "rack-c",
                "zone": "embedded",
                "weight": 1024,
                "endpoint": "m3db_data02:9000",
                "hostname": "m3db_data02",
                "port": 9000
            }
        ]
    }'
else
    curl -sSf -X POST ${COORDINATOR_API_HOST}/api/v1/services/m3db/placement/init -d '{
        "num_shards": 64,
        "replication_factor": 1,
        "instances": [
            {
                "id": "m3db_seed",
                "isolation_group": "rack-a",
                "zone": "embedded",
                "weight": 1024,
                "endpoint": "m3db_seed:9000",
                "hostname": "m3db_seed",
                "port": 9000
            }
        ]
    }'
fi

echo "Validating topology"
[ "$(curl -sSf ${COORDINATOR_API_HOST}/api/v1/services/m3db/placement | jq .placement.instances.m3db_seed.id)" == '"m3db_seed"' ]
echo "Done validating topology"

echo "Sleep until bootstrapped"
ATTEMPTS=12 TIMEOUT=2 retry_with_backoff  \
  '[ "$(curl -sSf ${M3DB_SEED_HOST}/health | jq .bootstrapped)" == true ]'

echo "Waiting until shards are marked as available"
ATTEMPTS=100 TIMEOUT=2 retry_with_backoff  \
  '[ "$(curl -sSf ${COORDINATOR_API_HOST}/api/v1/services/m3db/placement | grep -c INITIALIZING)" -eq 0 ]'

echo "Provisioning is done."
echo "Prometheus available at http://localhost:9090"
if [[ "$USE_MULTI_PROMETHEUS_NODES" = true ]] ; then
    echo "Prometheus replica is available at http://localhost:9091"
fi

echo "Grafana available at http://localhost:3000"
