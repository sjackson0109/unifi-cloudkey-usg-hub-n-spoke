#!/bin/bash
# Purpose: List symbolic links in the current location, and validate if the target exists or not. 
# Author:  Simon Jackson / @sjackson0109
# Created: 06/03/2024
echo "-------------------"
echo "link-name | result"
echo "-------------------"
for i in $(ls -l /root/links/ | grep ^l | awk '{ print $9 }'); do
    if [ -L "$i" ]; then
        target=$(readlink -f "$i")
        if [ ! -e "$target" ]; then
            echo "$i | BROKEN"
        else
            echo "$i | VALID"
        fi
    fi
done
echo "-------------------"