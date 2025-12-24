#!/bin/bash
# Randomly touch your .c and .o files
# Random weights 10000/6000 are adjustable

ls -1 *.c > cfiles    # '-1' always in one column
cat cfiles | sed -e 's/\.c$/.o/g' > ofiles

while read -r fname; do
    rn=$(echo $RANDOM) 
    if [ $rn -lt 10000 ]; then 
	touch $fname
        echo "$fname touched"
    fi
done < cfiles

while read -r fname; do
    rn=$(echo $RANDOM) 
    if [ $rn -lt 6000 ]; then 
	touch $fname
        echo "$fname touched"
    fi
done < ofiles
