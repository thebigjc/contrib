#!/usr/bin/env bash
ZK_USER=${ZK_USER:-"zookeeper"}
ZK_LOG_LEVEL=${ZK_LOG_LEVEL:-"INFO"}
ZK_DATA_DIR=${ZK_DATA_DIR:-"/var/lib/zookeeper/data"}
ZK_DATA_LOG_DIR=${ZK_DATA_LOG_DIR:-"/var/lib/zookeeper/log"}
ZK_LOG_DIR=${ZK_LOG_DIR:-"var/log/zookeeper"}
ZK_CONF_DIR=${ZK_CONF_DIR:-"/opt/zookeeper/conf"}
ZK_CLIENT_PORT=${ZK_CLIENT_PORT:-2181}
ZK_SERVER_PORT=${ZK_SERVER_PORT:-2888}
ZK_ELECTION_PORT=${ZK_ELECTION_PORT:-3888}
ZK_TICK_TIME=${ZK_TICK_TIME:-2000}
ZK_INIT_LIMIT=${ZK_INIT_LIMIT:-10}
ZK_SYNC_LIMIT=${ZK_SYNC_LIMIT:-5}
ZK_HEAP_SIZE=${ZK_HEAP_SIZE:-2G}
ZK_MAX_CLIENT_CNXNS=${ZK_MAX_CLIENT_CNXNS:-60}
ZK_MIN_SESSION_TIMEOUT=${ZK_MIN_SESSION_TIMEOUT:- $((ZK_TICK_TIME*2))}
ZK_MAX_SESSION_TIMEOUT=${ZK_MAX_SESSION_TIMEOUT:- $((ZK_TICK_TIME*20))}
ZK_SNAP_RETAIN_COUNT=${ZK_SNAP_RETAIN_COUNT:-3}
ZK_PURGE_INTERVAL=${ZK_PURGE_INTERVAL:-0}
ID_FILE="$ZK_DATA_DIR/myid"
ZK_CONFIG_FILE="$ZK_CONF_DIR/zoo.cfg"
LOGGER_PROPS_FILE="$ZK_CONF_DIR/log4j.properties"
JAVA_ENV_FILE="$ZK_CONF_DIR/java.env"
HOST=`hostname -s`
DOMAIN=`hostname -d`

function validate_env() {
    echo "Starting environment validation"
	if [ -z $ZK_ENSEMBLE ]; then
		echo "ZK_ENSEMBLE is a mandatory environment variable."
		exit 1
	fi
    echo "ZK_ENSEMBLE=$ZK_ENSEMBLE"
	
    SERVERS_LIST=$(echo $ZK_ENSEMBLE | tr ";" "\n")
	ZK_ENSEMBLE_LIST=""
	ID=1
	MY_ID=""
	for server in $SERVERS_LIST 
    do
    	ZK_ENSEMBLE_LIST+="$server.$DOMAIN:$ZK_SERVER_PORT:$ZK_ELECTION_PORT "
    	if [ "$server" = "$HOST" ]; then
    		MY_ID=$ID 
    	fi
    	ID=$((ID+1))
    done
    NUM_SERVERS=$((ID-1))
    if [ -z $MY_ID ]; then
    	echo "Could not find configured hostname $HOST in $ZK_ENSEMBLE"
    	exit 1
    fi

    echo "MY_ID=$MY_ID"
    echo "ZK_LOG_LEVEL=$ZK_LOG_LEVEL"
    echo "ZK_DATA_DIR=$ZK_DATA_DIR"
    echo "ZK_DATA_LOG_DIR=$ZK_DATA_LOG_DIR"
    echo "ZK_LOG_DIR=$ZK_LOG_DIR"
    echo "ZK_CLIENT_PORT=$ZK_CLIENT_PORT"
    echo "ZK_SERVER_PORT=$ZK_SERVER_PORT"
    echo "ZK_ELECTION_PORT=$ZK_ELECTION_PORT"
    echo "ZK_TICK_TIME=$ZK_TICK_TIME"
    echo "ZK_INIT_LIMIT=$ZK_INIT_LIMIT"
    echo "ZK_SYNC_LIMIT=$ZK_SYNC_LIMIT"
    echo "ZK_MAX_CLIENT_CNXNS=$ZK_MAX_CLIENT_CNXNS"
    echo "ZK_MIN_SESSION_TIMEOUT=$ZK_MIN_SESSION_TIMEOUT"
    echo "ZK_MAX_SESSION_TIMEOUT=$ZK_MAX_SESSION_TIMEOUT"
    echo "ZK_HEAP_SIZE=$ZK_HEAP_SIZE"
    echo "ZK_SNAP_RETAIN_COUNT=$ZK_SNAP_RETAIN_COUNT"
    echo "ZK_PURGE_INTERVAL=$ZK_PURGE_INTERVAL"
    echo "Enviorment validation successful"
}

function create_config() {
	rm -f $ZK_CONFIG_FILE
    echo "Creating ZooKeeper configuration in $ZK_CONFIG_FILE"
	echo "clientPort=$ZK_CLIENT_PORT" >> $ZK_CONFIG_FILE
    echo "dataDir=$ZK_DATA_DIR" >> $ZK_CONFIG_FILE
    echo "dataLogDir=$ZK_DATA_LOG_DIR" >> $ZK_CONFIG_FILE
    echo "tickTime=$ZK_TICK_TIME" >> $ZK_CONFIG_FILE
    echo "initLimit=$ZK_INIT_LIMIT" >> $ZK_CONFIG_FILE
    echo "syncLimit=$ZK_SYNC_LIMIT" >> $ZK_CONFIG_FILE
    echo "maxClientCnxns=$ZK_MAX_CLIENT_CNXNS" >> $ZK_CONFIG_FILE
    echo "minSessionTimeout=$ZK_MIN_SESSION_TIMEOUT" >> $ZK_CONFIG_FILE
    echo "maxSessionTimeout=$ZK_MAX_SESSION_TIMEOUT" >> $ZK_CONFIG_FILE
    echo "autopurge.snapRetainCount=$ZK_SNAP_RETAIN_COUNT" >> $ZK_CONFIG_FILE
    echo "autopurge.purgeInteval=$ZK_PURGE_INTERVAL" >> $ZK_CONFIG_FILE
    
    if [ $NUM_SERVERS -gt 1 ]; then 
        ID=1
        SERVERS_LIST=$(echo $ZK_ENSEMBLE | tr ";" "\n")
        for server in $ZK_ENSEMBLE_LIST 
        do
        	echo "server.$ID=$server" >> $ZK_CONFIG_FILE
        	ID=$((ID+1 ))
        done
    fi
    echo "ZooKeeper configuration file written to $ZK_CONFIG_FILE"
    cat $ZK_CONFIG_FILE
}

function create_data_dirs() {
    if [ ! -d $ZK_DATA_DIR  ]; then
        mkdir -p $ZK_DATA_DIR 
        chown -R $ZK_USER:$ZK_USER $ZK_DATA_DIR
        echo "Created ZooKeeper Data Directory"
        ls -ld $ZK_DATA_DIR >& 1
    else 
        echo "ZooKeeper Data Directory"
        ls -l -R $ZK_DATA_DIR >& 1
    fi
    

    if [ ! -d $ZK_DATA_LOG_DIR  ]; then
        mkdir -p $ZK_DATA_LOG_DIR 
        chown -R $ZK_USER:$ZK_USER $ZK_DATA_LOG_DIR
        echo "Created ZooKeeper Data Log Directory"
        ls -ld $ZK_DATA_LOG_DIR >& 1
    else
        echo "ZooKeeper Data Log Directory"
        ls -l -R $ZK_DATA_LOG_DIR >& 1
    fi
   
    if [ ! -d $ZK_LOG_DIR  ]; then
        mkdir -p $ZK_LOG_DIR 
        chown -R $ZK_USER:$ZK_USER $ZK_LOG_DIR
        echo "Created ZooKeeper Log Directory"
        ls -ld $ZK_LOG_DIR >& 1
    fi
    echo "Crateing ZooKeeper ensemble id file $ID_FILE"
    if [ ! -f $ID_FILE ]; then
        echo $MY_ID >> $ID_FILE
    fi
    echo "ZooKeeper ensemble id written to $ID_FILE"
    cat $ID_FILE
}

function create_log_props () {
	rm -f $LOGGER_PROPS_FILE
    echo "Creating ZooKeeper log4j configuration in $LOGGER_PROPS_FILE"
	echo "zookeeper.root.logger=CONSOLE" >> $LOGGER_PROPS_FILE
	echo "zookeeper.console.threshold="$ZK_LOG_LEVEL >> $LOGGER_PROPS_FILE
	echo "log4j.rootLogger=\${zookeeper.root.logger}" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE=org.apache.log4j.ConsoleAppender" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE.Threshold=\${zookeeper.console.threshold}" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE.layout=org.apache.log4j.PatternLayout" >> $LOGGER_PROPS_FILE
	echo "log4j.appender.CONSOLE.layout.ConversionPattern=%d{ISO8601} [myid:%X{myid}] - %-5p [%t:%C{1}@%L] - %m%n" >> $LOGGER_PROPS_FILE
	echo "Wrote log4j configuration to $LOGGER_PROPS_FILE"
	cat $LOGGER_PROPS_FILE 
}

function create_java_env() {
    rm -f $JAVA_ENV_FILE
    echo "Creating JVM configuration file $JAVA_ENV_FILE"
    echo "ZOO_LOG_DIR=$ZK_LOG_DIR" >> $JAVA_ENV_FILE
    echo "JVMFLAGS=\"-Xmx$ZK_HEAP_SIZE -Xms$ZK_HEAP_SIZE\"" >> $JAVA_ENV_FILE
    echo "Wrote JVM configuration to $JAVA_ENV_FILE"
    cat $JAVA_ENV_FILE
}

validate_env && create_config && create_log_props && create_data_dirs && create_java_env
