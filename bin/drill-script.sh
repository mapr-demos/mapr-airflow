#!/bin/bash

if [ -z "$1" ]; then
  echo 'Commit SHA argument is required!'
fi

SQL="use dfs.tmp;
alter session set \`store.format\`='parquet';
create table dfs.tmp.${1} as select _id, name, COUNT(album) as albums_number from (select _id, name, flatten(albums) as album from dfs.\`/apps/artists\`) group by _id, name;
"

sqlline -u jdbc:drill:zk=localhost:5181 <<< "$SQL"
