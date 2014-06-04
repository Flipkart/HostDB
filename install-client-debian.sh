#!/bin/bash
set -x
set -e

apt-get install libterm-readkey-perl libtext-diff-perl libyaml-syck-perl libwww-perl libio-socket-ssl-perl

rsync -a --exclude "DEBIAN" src/client/ /

echo "Setup complete."


