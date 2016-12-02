# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|
  config.vm.box = "debian/jessie64"

  config.vm.synced_folder '.', '/vagrant'
  #config.vm.synced_folder '.', '/vagrant_data'

  config.vm.provision "shell", inline: <<-SHELL

     # install what we need
     sudo apt-get update
     sudo apt-get install -y git-core \
         apache2 \
         libapache2-mod-fcgid \
         libyaml-syck-perl \
         libnet-ldap-perl \
         liblog-log4perl-perl \
         libcrypt-cbc-perl \
         libcgi-fast-perl \
         libfcgi-perl \
         libio-socket-inet6-perl \
         libsocket6-perl \
         liblog-dispatch-perl \
         libcrypt-blowfish-perl \
         libnetaddr-ip-perl

    # create self signed cert
    sudo openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
        -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com" \
        -keyout /etc/ssl/private/apache-selfsigned.key \
        -out /etc/ssl/certs/apache-selfsigned.crt

    # setup data dir
    NDIR=`grep namespace_dir /vagrant/src/server/etc/hostdb/server_conf.yaml | awk '{print $2}'`
    sudo mkdir -p $NDIR/hosts/.perms
    sudo mkdir -p $NDIR/tags/.perms
    sudo mkdir -p $NDIR/tags/.members

    sudo echo "--- yaml host conf" > $NDIR/hosts/server1.yourdomain.com
    sudo echo "--- yaml host conf" > $NDIR/hosts/server2.yourdomain.com
    sudo echo "--- yaml tag conf" > $NDIR/tags/tag1
    sudo echo "--- yaml tag conf" > $NDIR/tags/tag2
    sudo echo "--- yaml tag conf" > $NDIR/tags/tag3
    sudo echo "server1.yourdomain.com" > $NDIR/tags/.members/tag1
    sudo echo "server2.yourdomain.com" > $NDIR/tags/.members/tag2
    sudo echo -e '@tag1\\n@tag2' > $NDIR/tags/.members/tag3
    sudo echo -e "---\\nadmin:\\n  data: RW" > $NDIR/hosts/.perms/.default
    sudo echo -e "---\\nadmin:\\n  data: RW\\n  members: RW" > $NDIR/tags/.perms/.default
    pushd $NDIR
    sudo git init . && git add * && git commit --allow-empty -am "init"
    popd

    # copy config files
    sudo cp -R /vagrant/src/server/etc/hostdb /etc/
    sudo cp -R /vagrant/src/server/etc/cron.d/hostdb /etc/cron.d/hostdb
    sudo cp -R /vagrant/src/server/etc/logrotate.d/hostdb /etc/logrotate.d/
    sudo cp -R /vagrant/src/server/etc/apache2/sites-available/hostdb /etc/apache2/sites-available/hostdb

    # adjust apache config
    sudo sed -i 's/SSLCACertificateFile.*//' /etc/apache2/sites-available/hostdb
    sudo sed -i 's/crt\\/yourdomain.crt/certs\\/apache-selfsigned.crt/' /etc/apache2/sites-available/hostdb
    sudo sed -i 's/crt\\/yourdomain.key/private\\/apache-selfsigned.key/' /etc/apache2/sites-available/hostdb

    # link stuff, so we can edit it in /vagrant and see the results more or less live
    sudo ln -s /vagrant/src/server/usr/lib/cgi-bin/hostdb_rest.fcgi /usr/lib/cgi-bin/hostdb_rest.fcgi
    sudo ln -s /vagrant/src/server/usr/local/lib/site_perl /usr/local/libsite_perl
    sudo ln -s /vagrant/src/server/usr/local/bin/hostdb_git_gc.sh /usr/local/bin/hostdb_git_gc.sh
    sudo ln -s /vagrant/src/webui/var/www/hostdb /var/www/hostdb

    # finish up
    sudo /vagrant/src/server/DEBIAN/postinst
   SHELL
end
