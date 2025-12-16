#!/usr/bin/bash

for arg in $@; do
 if [ -d $arg ];
 then
  a=$(ls -lR $arg | grep ^- | wc -l)
  echo $arg: has $a files
 else
  echo "$arg: not directory"
 fi
done
