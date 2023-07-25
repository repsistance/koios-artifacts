#!/bin/bash
DB_NAME=cexplorer

tip=$(psql ${DB_NAME} -qbt -c "select extract(epoch from time)::integer from block order by id desc limit 1;" | xargs)

if [[ $(( $(date +%s) - tip )) -gt 300 ]]; then
  echo "$(date +%F_%H:%M:%S) Skipping as database has not received a new block in past 300 seconds!" && exit 1
fi

echo "$(date +%F_%H:%M:%S) Running active stake cache update..."

# High level check in db to see if update needed at all (should be updated only once on epoch transition)
[[ $(psql ${DB_NAME} -qbt -c "SELECT grest.active_stake_cache_update_check();" | tail -2 | tr -cd '[:alnum:]') != 't' ]] &&
  echo "No update needed, exiting..." &&
  exit 0

db_last_epoch_no=$(psql ${DB_NAME} -qbt -c "SELECT MAX(NO) from EPOCH;" | tr -cd '[:alnum:]')

# Count current epoch entries processed by db-sync
db_epoch_stakes_count=$(psql ${DB_NAME} -qbt -c "SELECT COUNT(1) FROM EPOCH_STAKE WHERE epoch_no = ${db_last_epoch_no};" | tr -cd '[:alnum:]')

# Stakes have been validated, run the cache update
psql ${DB_NAME} -qbt -c "SELECT GREST.active_stake_cache_update(${db_last_epoch_no});" 1>/dev/null 2>&1
echo "$(date +%F_%H:%M:%S) Job done!"
