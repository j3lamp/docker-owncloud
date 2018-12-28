# ownCloud docker image


Easy usable docker image for [ownCloud](http://owncloud.org), the community fork of ownCloud.

## Features

* Uses latest stable version of **Alpine Linux**, bundled with **PHP 7** and **NGinx**.
* GPG check during building process.
* APCu already configured.
* LDAP support.
* Cron runs every 15 minutess (No need for web or AJAX cron).
* Persistence for data, configuration and apps.
* ownCloud included apps that are persistent will be automatically updated during start.
* Works with MySQL/MariaDB and PostgreSQL (server not included).
* Supports uploads up to 10GB.

## Container environment

### Included software

* Alpine Linux
* **PHP 7**
* APCu
* NGinx
* cron
* SupervisorD

Everything is bundled in the newest stable version.

### Tags

* **latest**: latest stable ownCloud version (PHP 7)
* **X.X.X**: stable version tags of ownCloud (e.g. v9.0.52)
* **develop**: latest development branch (may be unstable)

### Build-time arguments
* **OWNCLOUD_GPG**: Fingerprint of ownCloud signing key
* **OWNCLOUD_VERSION**: ownCloud version to install
* **UID**: User ID of the owncloud user (default 1503)
* **GID**: Group ID of the owncloud user (default 1503)

### Exposed ports
- **80**: NGinx webserver running ownCloud.

### Volumes
- **/data** : All data, including config and user downloaded apps (in subfolders).

## Usage

### Standalone

You can run ownCloud without a separate database, but I don't recommend it for production setups as it uses SQLite. Another solution is to use an external database provided elsewhere, you can enter the credentials in the installer.

1. Pull the image: `docker pull j3lamp/owncloud`
2. Run it: `docker run -d --name owncloud -p 80:80 -v my_local_data_folder:/data j3lamp/owncloud` (Replace *my_local_data_folder* with the path where do you want to store the persistent data)
3. Open [localhost](http://localhost) and profit!

The first time you run the application, you can use the ownCloud setup wizard to install everything. Afterwards it will run directly.

### With a database container

For standard setups I recommend the use of MariaDB, because it is more reliable than SQLite. For example, you can use the offical docker image of MariaDB. For more information refer to the according docker image.

```
# docker pull rootlogin/owncloud && docker pull mariadb:10
# docker run -d --name owncloud_db -v my_db_persistence_folder:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=supersecretpassword -e MYSQL_DATABASE=owncloud -e MYSQL_USER=owncloud -e MYSQL_PASSWORD=supersecretpassword mariadb:10
# docker run -d --name owncloud --link owncloud_db:owncloud_db -p 80:80 -v my_local_data_folder:/data j3lamp/owncloud
```

*The auto-connection of the database to owncloud is not implemented yet. This is why you need to do that manually.*

## Configuration

You can configure ownCloud via the occ command:

```
# docker exec -ti owncloud occ [...YOUR COMMANDS...]
```

The command uses the same user as the webserver.

## Other

### Migrate from OwnCloud

You can easily migrate an existing OwnCloud to this ownCloud docker image.

**Before starting, always make a backup of your old OwnCloud instance. I told you so!**

1. Enable the maintenance mode on your old OwnCloud instance, e.g. `sudo -u www-data ./occ maintenance:mode --on`
2. Create a new folder e.g. /var/my_owncloud_data
3. Create a new subfolder called "config" and copy the config.php from your existing instance in there.
4. Copy your existing "data" folder to */var/my_owncloud_data*/data
5. Start the docker container: `docker run -d --name owncloud -p 80:80 -v /var/my_owncloud_data:/data j3lamp/owncloud`
6. Wait until everything is running.
7. Start the ownCloud migration command: `docker exec owncloud occ upgrade`
8. Disable the maintenance mode of ownCloud: `docker exec owncloud occ maintenance:mode --off`
9. **Profit!**

### Run container with systemd

I usually run my containers on behalf of systemd, with the following config:

```
[Unit]
Description=Docker - ownCloud container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker run -p 127.0.0.1:8000:80 -v /data/owncloud:/data --name owncloud j3lamp/owncloud
ExecStop=/usr/bin/docker stop -t 2 owncloud ; /usr/bin/docker rm -f owncloud

[Install]
WantedBy=default.target
```

### NGinx frontend proxy

This container does not support SSL or similar and is therefore not made for running directly in the world wide web. You better use a frontend proxy like another NGinx.

Here are some sample configs (The config need to be adapted):

```
server {
    listen 80;
    server_name cloud.example.net;

    # ACME handling for Letsencrypt
    location /.well-known/acme-challenge {
    alias /var/www/letsencrypt/;
    default_type "text/plain";
        try_files $uri =404;
    }

    location / {
        return 302 https://$host$request_uri;
    }
}

server {
    listen 443 ssl spdy;
    server_name cloud.example.net;

    ssl_certificate /etc/letsencrypt.sh/certs/cloud.example.net/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt.sh/certs/cloud.example.net/privkey.pem;
    ssl_trusted_certificate /etc/letsencrypt.sh/certs/cloud.example.net/chain.pem;
    ssl_dhparam /etc/nginx/dhparam.pem;
    ssl_protocols TLSv1 TLSv1.1 TLSv1.2;

    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 30m;

    ssl_prefer_server_ciphers on;
    ssl_ciphers "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!DES:!MD5:!PSK:!RC4";

    ssl_stapling on;
    ssl_stapling_verify on;

    add_header Strict-Transport-Security "max-age=31536000";

    access_log  /var/log/nginx/docker-owncloud_access.log;
    error_log   /var/log/nginx/docker-owncloud_error.log;

    location / {
      proxy_buffers 16 4k;
      proxy_buffer_size 2k;

      proxy_read_timeout 300;
      proxy_connect_timeout 300;
      proxy_redirect     off;

      proxy_set_header   Host              $http_host;
      proxy_set_header   X-Real-IP         $remote_addr;
      proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
      proxy_set_header   X-Frame-Options   SAMEORIGIN;

      client_max_body_size 10G;

      proxy_pass http://127.0.0.1:8000;
    }
}
```

## Frequently Asked Questions

**Why does the start take so long?**

When you run the container it will reset the permissions on the /data folder. This means if you have a lot of data, it takes some time. This helps to avoid permission issues.

## Overwritten config

Some parameters in the ownCloud configuration will be overwritten by the file in `root/opt/owncloud/config/docker.config.php`

## Group/User ID

You can change the numerical user id and group id via build arguments.

```
$ git clone https://github.com/j3lamp/docker-owncloud.git && cd docker-owncloud
$ docker build -t j3lamp/owncloud --build-arg UID=1000 --build-arg GID=1000 .
$ docker run -p 80:80 j3lamp/owncloud
```

## References

This is based heavily on [https://github.com/chrootLogin/docker-nextcloud](https://github.com/chrootLogin/docker-nextcloud).
