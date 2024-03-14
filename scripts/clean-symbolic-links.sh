#!/bin/bash
# Purpose: Loop through symbolic links in the target location, and remove sym links if the target does not exist 
# Author:  Simon Jackson / @sjackson0109
# Created: 06/03/2024
echo "-------------------"
echo "cleanup of links"
echo "-------------------"
for i in $(ls -l /root/links/ | grep ^l | awk '{ print $9 }'); do
    if [ -L "$i" ]; then
        target=$(readlink -f "$i")
        if [ ! -e "$target" ]; then
            echo "rm /root/links/$i -f"
        fi
    fi
done
echo "-------------------"