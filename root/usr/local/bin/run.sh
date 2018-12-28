#!/bin/bash

# SIGTERM-handler
term_handler() {
  if [ $pid -ne 0 ]; then
    kill -SIGTERM "$pid"
    wait "$pid"
  fi
  exit 143; # 128 + 15 -- SIGTERM
}

# Migration stuff
if [ -d /data/apps ]; then
  echo "Migrate apps... (This will take some time...)"

  for DIR in $(find /data/apps ! -path /data/apps -type d -maxdepth 1); do
    DIR=${DIR##*/}

    # Delete apps that are delivered with Nextcloud
    if [ -d /opt/owncloud/apps/$DIR ]; then
      rm -rf /data/apps/$DIR
    fi
  done

  if [ -d /data/userapps ]; then
    mv /data/apps/* /data/userapps/
    rm -rf /data/apps
  else
    mv /data/apps /data/userapps
  fi
fi

# Bootstrap application
echo "Preparing environment... (This will take some time...)"

if [ ! -d /data/config ]; then
  mkdir /data/config
fi

cp -f /opt/owncloud/config/config.sample.php /data/config/
cp -f /opt/owncloud/config/docker.config.php /data/config/

if [ ! -d /data/data ]; then
  mkdir /data/data
fi

if [ ! -d /data/tmp ]; then
  mkdir /data/tmp
fi

if [ ! -d /data/userapps ]; then
  mkdir /data/userapps
fi

rm -rf /opt/owncloud/data /opt/owncloud/config
ln -s /data/data /opt/owncloud/
ln -s /data/config /opt/owncloud/
ln -s /data/userapps /opt/owncloud/

chown -R owncloud:owncloud /data /opt/owncloud/config

# run application
echo "Starting supervisord..."
exec /usr/bin/supervisord -c /etc/supervisord.conf
