#/bin/sh -x
PRIMARY_HOST_NAME=db1
RECOVERY_HOST_NAME=db2
PRIMARY_PORT=5432
STANDBY_PORT=5432

SOURCE_CLUSTER=/var/lib/pgsql/data
DEST_CLUSTER=/var/lib/pgsql/data

psql -p $PRIMARY_PORT -c "SELECT pg_start_backup('file_based_log_shipping', true)" postgres

/usr/bin/rsync -C -a -c --delete --exclude postmaster.pid \
--exclude postgresql.conf --exclude bak.trigger \
--exclude postmaster.opts --exclude pg_log \
--exclude recovery.conf --exclude recovery.done \
--exclude pg_xlog $SOURCE_CLUSTER/ $RECOVERY_HOST_NAME:$DEST_CLUSTER/

ssh -T $RECOVERY_HOST_NAME /bin/rm -rf $DEST_CLUSTER/pg_xlog
ssh -T $RECOVERY_HOST_NAME /bin/mkdir $DEST_CLUSTER/pg_xlog
ssh -T $RECOVERY_HOST_NAME /bin/chmod 700 $DEST_CLUSTER/pg_xlog
ssh -T $RECOVERY_HOST_NAME /bin/rm -rf $DEST_CLUSTER/recovery.done
ssh -T $RECOVERY_HOST_NAME "/bin/cat > $DEST_CLUSTER/recovery.conf <<EOF
standby_mode = on
primary_conninfo = 'port=$PRIMARY_PORT user=postgres host=$PRIMARY_HOST_NAME'
recovery_target_timeline = 'latest'
trigger_file = '/var/lib/pgsql/data/bak.trigger'
EOF"

ssh -T $RECOVERY_HOST_NAME "sed -i 's/$PRIMARY_PORT/$STANDBY_PORT/g' $DEST_CLUSTER/postgresql.conf"
psql -p $PRIMARY_PORT -c "SELECT pg_stop_backup()" postgres
