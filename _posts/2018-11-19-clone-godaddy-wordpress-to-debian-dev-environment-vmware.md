---
layout: post
title: "Clone GoDaddy Wordpress Installation to Development Environment on Debian Linux & VMWare"
author: "brinkt"
date: 2018-11-19
tags: godaddy wordpress debian linux vmware mariadb
---

This guide clones a *Wordpress* installation on *GoDaddy* to a development environment on Debian 9.5 Linux and *VMWare*, making it available via a subdomain pointing to the external network's IP address. This allows a *Wordpress* child theme to be developed locally and previewed remotely before being deployed to production.

### Step 1: Install Debian 9.5 netinst

Complete the following guide: [Install Debian Stretch on VMWare with Custom Iptables NAT]({% post_url 2018-11-09-install-debian-vmware-iptables-nat %})

Add the following iptables rules to port forward port 80:

```
-A FORWARD -i eth0 -o vnet1 -p tcp -m conntrack --ctstate NEW --dport 80 -j ACCEPT
```

Add the following within `nat` section of rules:

```
-A PREROUTING -d 192.168.1.100 -p tcp --dport 80 -j DNAT --to 172.17.0.10:80
```

In this case, `192.168.1.100` is the local network IP address of the machine running VMWare.

### Step 2: Clone GoDaddy Wordpress

In `GoDaddy => Hosting`, find your `SFTP user` and corresponding password. Use this to navigate to `sftp://user@domain/home/user/html/`, which is your GoDaddy Wordpress installation directory.

Copy the directory `wp-content/` and file `wp-config.php` to your local development machine.

Modify `wp-config.php` by commenting out the require statement to `gd-config.php` since we chose not to include it:

```
//require_once( dirname( __FILE__ ) . '/gd-config.php' );
```

To dump MySQL database, use GoDaddy `phpMyAdmin` url and log in with provided user and password. Select the database with same name as username and click on the `Export` tab.

Save this SQL dump text to file `database.sql` on your local development machine.

Copy these to virtual server:

```
local$ rsync -vrc wp-content wp-config.php database.sql anon@172.17.0.10:/home/anon/
```

### Step 3: Install Apache, MySql, PHP

From development machine, open a remote terminal to virtual server and obtain root:

```
local$ ssh -l anon 172.17.0.10
$ su
```

#### Install Apache Web Server

```
$ apt-get install apache2 apache2-utils 
```

Enable and start `apache2`

```
$ systemctl enable apache2
$ systemctl start apache2
```

#### Install MySQL Database

\*\*Consider installing latest *MariaDB* `mariadb-server` instead of *MySQL* `mysql-server` using the following repo: [https://downloads.mariadb.org/mariadb/repositories](https://downloads.mariadb.org/mariadb/repositories)\*\*

```
$ apt-get install mysql-client mysql-server
```

Set the root password, secure installation, and restart:

```
$ mysql_secure_installation
```

Disable DNS lookups in `/etc/mysql/my.cnf`:

```
#
# * Basic Settings
# 
skip-name-resolve
```

This fixes a problem where first page request is very slow, but subsequent page requests are fast, and only when accessing the database.

#### Install PHP

```
$ apt-get install php7.0 php7.0-mysql libapache2-mod-php7.0 php7.0-cli php7.0-cgi php7.0-gd
```

Create `info.php` file:

```
vim /var/www/html/info.php
```

With the following contents:

```php
<?php 
phpinfo();
?>
```

Visit [http://172.17.0.10/info.php](http://172.17.0.10/info.php) to ensure everything is working properly.

### Step 4: Install Wordpress

```
$ wget -c http://wordpress.org/latest.tar.gz
$ tar -xzvf latest.tar.gz
```

Move wordpress files to apache2 location:

```
$ rsync -av wordpress/* /var/www/html/
```

Set the correct file permissions:

```
$ chown -R www-data:www-data /var/www/html/
$ chmod -R 755 /var/www/html/
```

### Step 5: Enable Apache mod_rewrite & .htaccess

Create Wordpress `.htaccess` file:

```
$ vim /var/www/html/.htaccess
```

With the contents:

```
# BEGIN WordPress
<IfModule mod_rewrite.c>
RewriteEngine On
RewriteBase /
RewriteRule ^index\.php$ - [L]
RewriteCond %{REQUEST_FILENAME} !-f
RewriteCond %{REQUEST_FILENAME} !-d
RewriteRule . /index.php [L]
</IfModule>
# END WordPress
```

Save, exit, then change owner and  permissions:

```
$ chown www-data:www-data /var/www/html/.htaccess
$ chmod 644 /var/www/html/.htaccess
```

Edit `apache2.conf` to allow override:

```
$ vim /etc/apache2/apache2.conf
```

Adjust AllowOverride within `/var/www/`:

```
<Directory /var/www/>
  AllowOverride All
</Directory>
```

Enable `mod_rewrite` and restart apache2:

```
$ a2enmod rewrite
$ service apache2 restart
```

### Step 6: Setup MySQL Database

Use information within `wp-config.php` to setup MySQL database:

```
$ mysql -u root -p 
```

Enter password setup during MySQL installation.

Create table and grant privileges, replacing `DB_NAME`, `DB_USER`, `DB_PASSWORD` with correct info:

```
mysql> CREATE DATABASE DB_NAME;
mysql> GRANT ALL PRIVILEGES ON DB_NAME.* TO 'DB_USER'@'localhost' IDENTIFIED BY 'DB_PASSWORD';
mysql> FLUSH PRIVILEGES;
mysql> EXIT;
```

Import `database.sql`:

```
$ mysql -u root -p DB_NAME < database.sql
```

Log back into database:

```
$ mysql -u root -p DB_NAME
```

To list tables:

```
mysql> show tables;
```

Update `wp_options` table to use development subdomain:

```
mysql> UPDATE wp_rygxqxy6yx_options SET option_value = 'http://dev1.nanobasis.com' WHERE option_id = 1;
```

Update `wp_users` table to set login password of default user:

```
mysql> UPDATE wp_rygxqxy6yx_users SET user_pass = MD5('newpassword') WHERE user_login = 'username';
```

Exit database.

### Step 7: Finish Wordpress Setup

Copy `wp-content/` to installation directory:

```
$ rsync -vrc wp-content/ /var/www/html/wp-content/
$ chmod -R 755 /var/www/html/wp-content
```

Copy `wp-config.php` to installation directory:

```
$ mv wp-config.php /var/www/html/
$ chmod 755 /var/www/html/wp-config.php
```

Set the correct ownership of entire installation directory:

```
$ chown -R www-data:www-data /var/www/html/
```

Restart `apache2` and `mysql`:

```
$ service mysql restart
$ service apache2 restart
```

Assuming port forwarding is set up correctly on your router, you should be able to view the Wordpress install on the subdomain pointing to your external IP address.