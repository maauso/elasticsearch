#!/bin/bash

#####################################################################################
# Backup tool for Elasticsearch from QA and all production machines, you can put scrptis in all Elasticsearch servers. 
# @author: maauso
# @version: 2014-11-01 18:51
# This script colud be manage with puppet
#####################################################################################

repository="repository name"
servers="Servers"
mountpoint="mountpointpath"
# random execution
sleep `/usr/bin/expr $RANDOM % 15`

# check necessary tools
command -v curator >/dev/null 2>&1 || exit 1
command -v curl >/dev/null 2>&1 || exit 1
pid=`pgrep curator` && kill -9 $pid

function clean {
if [ -f /$mountpoint/$repository/backup.lck ]
then
   echo "It seems that there is already another server working"
else
   touch /$mountpoint/$repository/backup.lck && echo $HOSTNAME > /$mountpoint/$repository/backup.lck
   days=7
   curator snapshot --delete-older-than $days --repository $1
   rm -rf /$mountpoint/$repository/backup.lck
fi
}

function backup {

if [ -f /$mountpoint/$repository/backup.lck ]
then

 echo "It seems that there is already another server working"

else

  touch /$mountpoint/$repository/backup.lck && echo $1 > /$mountpoint/$repository/backup.lck

  if [[ `df -h | grep es_backup | awk '{print $5}' | tr -d "%"` -lt 85 ]]; then
    date=`date '+%y%m%d'`
    curl -s -XGET "http://$1:9200/_cluster/health?pretty=true" | grep 'status' | grep 'green'
      if [[ '0' -ne "$?"  ]]; then
        echo "This cluster is not so good, we went out for caution" && exit 1
      else
        curl -s -XGET "http://$1:9200/_snapshot/" | grep location
        if [[ '0' -ne "$?"  ]]; then
          echo "We need repository , http://www.elasticsearch.org/guide/en/elasticsearch/reference/current/modules-snapshots.html " && exit 1
        else
          curator --timeout 3600  snapshot  --repository $2 --snapshot-name $date --all-indices
          rm -rf /$mountpoint/$repository/backup.lck
        fi
      fi
  else
    echo "We need more disk space"
  fi
fi
}


if [[ $servers =~ .*$HOSTNAME*.  ]]; then

  clean  $repository
  backup $HOSTNAME $repository

fi
