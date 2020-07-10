---
layout: post
title: "Install Jackal XMPP Server as Service on Debian Linux"
author: "brinkt"
date: 2018-11-29
tags: jackal xmpp tls debian linux vmware mariadb
---

This guide installs *jackal* XMPP server as a service on boot, enabling tls encryption with a self-signed certificate, onto Debian 9.5 Linux using MariaDB as the database. *jackal* is built from go source and installed as a service within: */etc/init.d/*

## Step 1: Install MariaDB

Add the latest `MariaDB` apt repository from [https://downloads.mariadb.org/mariadb/repositories](https://downloads.mariadb.org/mariadb/repositories):

```
sudo apt-get install software-properties-common dirmngr
sudo apt-key adv --recv-keys --keyserver keyserver.ubuntu.com 0xF1656F24C74CD1D8
sudo add-apt-repository 'deb [arch=amd64,i386,ppc64el] http://mirrors.syringanetworks.net/mariadb/repo/10.3/debian stretch main'
```

Once key is imported, update and install from repository:

```
sudo apt-get update
sudo apt-get install mariadb-client mariadb-server mysql-common
```

## Step 2: Generate self-signed certificate

Generate a self-signed certificate to `/etc/ssl/localcerts/`:

```
sudo apt-get install openssl
sudo mkdir -p /etc/ssl/localcerts
sudo openssl req -new -x509 -days 365 -nodes -out /etc/ssl/localcerts/xmpp.pem -keyout /etc/ssl/localcerts/xmpp.key
sudo chmod 600 /etc/ssl/localcerts/xmpp*
```

Be sure to use the correct domain name when asked.

## Step 3: Install go

Download latest go binary from [golang.org/dl](https://golang.org/dl/)

Extract to `/usr/local`, run:

    sudo tar -C /usr/local -xzf go1.11.2.linux-amd64.tar.gz

Create go home dir if doesn't already exist, run:

    if [ ! -d $HOME/go ]; then mkdir $HOME/go; fi

Open `~/.profile` for editing, run:

    nano ~/.profile

Append the following, then save/exit:

    export PATH=$PATH:/usr/local/go/bin
    export GOPATH=$HOME/go
    export PATH=$PATH:$GOPATH/bin

Source updated profile, run:

    source ~/.profile

## Step 4: Install jackal & configure database

Grab source through `go get`:

    go get github.com/ortuman/jackal

Build jackal:

    cd $GOPATH/src/github.com/ortuman/jackal
    go build

Copy jackal to `/usr/bin/`:

    sudo mv jackal /usr/bin/jackal

Create jackal database:

```
mysql -u root -p
mysql> CREATE DATABASE jackal;
mysql> GRANT ALL ON jackal.* TO 'jackal'@'127.0.0.1' IDENTIFIED BY 'password';
mysql> exit;
```

Import schema into database:

```
wget https://raw.githubusercontent.com/ortuman/jackal/master/sql/mysql.sql
mysql -D jackal -u jackal -p < mysql.sql
rm mysql.sql
```

Using the password setup while creating database.

## Step 5: Configure jackal

Create jackal config:

```
cp $GOPATH/src/github.com/ortuman/jackal/example.jackal.yml jackal.yml
sudo mkdir -p /opt/jackal
sudo mv jackal.yml /opt/jackal/jackal.yml
```

Update `jackal.yml` to configure domain and tls:

    sudo nano /opt/jackal/jackal.yml

Refer to the following:

```
router:
  hosts:
    - name: xmpp.nanobasis.com
      tls:
        privkey_path: "/etc/ssl/localcerts/xmpp.key"
        cert_path: "/etc/ssl/localcerts/xmpp.pem"
```

## Step 6: Add jackal user & set permissions

Create user and group `jackal`:

    sudo useradd -s /bin/sh -d /nonexistent jackal

Take ownership of certificates and `/opt/jackal/`:

    sudo chown jackal:jackal /etc/ssl/localcerts/xmpp*
    sudo chown -R jackal:jackal /opt/jackal

## Step 7: Create jackal as init.d service

Create new init.d service `jackald`:

    sudo nano /etc/init.d/jackald

With the following:

```
#!/bin/sh
### BEGIN INIT INFO
# Provides:          jackald
# Required-Start:    $local_fs $network $syslog mysqld
# Required-Stop:     $local_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# X-Interactive:     true
# Short-Description: jackal XMPP server
# Description:       Start the jackal XMPP server
### END INIT INFO

startJackal () {
  cd /opt/jackal
  su -c "jackal --config=jackal.yml" jackal &> /dev/null
}

stopJackal() {
  pid=$(cat /opt/jackal/jackal.pid)
  if [ "$pid" != "" ]; then
    kill $1 $pid &
  fi
}

restartJackal () {
  stopJackal $1
  startJackal &
}

case "$1" in
  start)
    echo "Starting jackal..."
    startJackal &
    ;;
  stop)
    echo "Stopping jackal..."
    stopJackal -2
    ;;
  kill)
    echo "Killing jackal..."
    stopJackal -9
    ;;
  restart)
    echo "Restarting jackal..."
    restartJackal -2
    ;;
  force-reload)
    echo "Force reloading jackal..."
    restartJackal -9
    ;;
  status)
    if [ "$(cat /opt/jackal/jackal.pid)" != "" ]; then
      echo "jackal is presumed to be running."
    else
      echo "jackal is not running."
    fi
    ;;
  *)
    echo "Usage: /etc/init.d/jackald {start|stop|kill|restart|force-reload|status}"
    exit 1
    ;;
esac

exit 0

```

Make `jackald` executable:

    sudo chmod +x /etc/init.d/jackald

Start `jackal` on boot:

    sudo update-rc.d jackald defaults

To later remove from startup:

    sudo update-rc.d -f jackald remove
