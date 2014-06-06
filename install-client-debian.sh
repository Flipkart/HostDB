#!/bin/bash
set -x
set -e

apt-get install libterm-readkey-perl libtext-diff-perl libyaml-syck-perl libwww-perl libio-socket-ssl-perl

rsync -a --exclude "DEBIAN" src/client/ /

set +x
echo "------------------------------------------------------"
echo "Setup Compelte. Configure server name in /etc/hostdb/client_conf.yaml"
echo "------------------------------------------------------"

