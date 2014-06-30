#!/bin/bash
set -e
NDIR=`grep namespace_dir /etc/hostdb/server_conf.yaml | awk '{print $2}'`
cd $NDIR && git gc

