#!/bin/bash
# Purpose: Create symbolic links in the current site_name, and validate if the target exists or not. 
# Author:  Simon Jackson / @sjackson0109
# Created: 28/02/2024

# Set the path to the CSV file
csv_file="./config/sites.csv"

# Ensure the target directory exists
mkdir -p "$target_dir"

# Read the CSV file line by line
while IFS=, read -r local_site local_octetid local_subnets local_asn eth2_percent eth3_percent location remote_site remote_asn tun0_peer tun0_psk tun0_vti tun0_bgp_weight tun0_bgp_metric tun1_peer tun1_psk tun1_vti tun1_bgp_weight tun1_bgp_metric unifi_site_id; do
    # Remove double quotes from variables
    local_site=$(echo "${local_site}" | cut -d',' -f1 | tr -d '"')
    unifi_site_id=$(echo "${unifi_site_id}" | cut -d',' -f1 | tr -d '"')

    # Create symbolic links based on unifi_site_id
    ln -sf "/data/unifi/data/sites/$unifi_site_id" "./links/$local_site"
done < "$csv_file"
