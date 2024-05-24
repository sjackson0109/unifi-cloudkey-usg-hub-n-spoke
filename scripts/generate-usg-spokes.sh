#!/bin/bash
# Purpose: Loop through a CSV data file and several nested JSON files to build a new Unifi config file (config.gateway.json).
# Fundamentally, automate the entire configuration for a 'SPOKES' of a Hub-n-Spoke network design.
# Author: Simon Jackson / @sjackson0109
# Code: https://github.com/sjackson0109/unifi-cloudkey-usg-hub-n-spoke
# Created: 07/03/2024
# Updated: 24/04/2024

# Define template folder, output path, and other global variables
template_folder="/root/templates/usg"
csv_file="/root/config/wheel.csv"   # All fields should be encapsulated in quotes, comma-separated
output_folder="/root/generated"
support="networking@company.com"
domain_name="company.com"
syslog_server="syslog.company.com"

# Read the hub JSON template files
spokes_main=$(<"${template_folder}/spokes.json")
spokes_ike_groups=$(<"${template_folder}/spokes-ike-groups.json")
spokes_esp_groups=$(<"${template_folder}/spokes-esp-groups.json")
spokes_ipsec_tun0=$(<"${template_folder}/spokes-ipsec-tun0.json")
spokes_ipsec_tun1=$(<"${template_folder}/spokes-ipsec-tun1.json")
spokes_vti0=$(<"${template_folder}/spokes-vti0.json")
spokes_vti1=$(<"${template_folder}/spokes-vti1.json")
spokes_bgp_neighbor0=$(<"${template_folder}/spokes-bgp-neighor0.json")
spokes_bgp_neighbor1=$(<"${template_folder}/spokes-bgp-neighor1.json")

echo "####################################"
echo "#               START              #"    
echo "####################################"
# Read the header row of the CSV file to get the column names
IFS=, read -r -a columns < <(sed 's/"//g' <<< "$(head -n 1 "$csv_file")")
echo "#          CSV IMPORTED            #"

# Process the hub CSV file
echo "# Processing file:                 #"
#echo "#  ${output_path}/wheel.csv           #"
printf "#  %-30s  #\n" "${output_path}/wheel.csv"
config="$spokes_main"
# Escape special characters, and remove row-feeds, and quotes for ike_groups, esp_groups, and ipsec_tunnels sections
spokes_ike_groups=$(printf "$spokes_ike_groups" | tr -d '\n' | sed 's/"/\\"/g')
spokes_esp_groups=$(printf "$spokes_esp_groups" | tr -d '\n' | sed 's/"/\\"/g')
spokes_ipsec_tun0=$(printf "$spokes_ipsec_tun0" | tr -d '\n' | sed 's/"/\\"/g')
spokes_ipsec_tun1=$(printf "$spokes_ipsec_tun1" | tr -d '\n' | sed 's/"/\\"/g')
spokes_vti0=$(printf "$spokes_vti0" | tr -d '\n' | sed 's/"/\\"/g')
spokes_vti1=$(printf "$spokes_vti1" | tr -d '\n' | sed 's/"/\\"/g')
spokes_bgp_neighbor0=$(printf "$spokes_bgp_neighbor0" | tr -d '\n' | sed 's/"/\\"/g')
spokes_bgp_neighbor1=$(printf "$spokes_bgp_neighbor1" | tr -d '\n' | sed 's/"/\\"/g')

# Substitute ike_groups, and esp_groups sections, ipsec_tunnels and bgp_neighbors
config=$(sed "s|\"{{ ike_groups }}\"|$spokes_ike_groups|g" <<< "$config" )
config=$(sed "s|\"{{ esp_groups }}\"|$spokes_esp_groups|g" <<< "$config" )
config=$(sed "s|\"{{ ipsec_tunnels }}\"|\"212.161.51.180\": $spokes_ipsec_tun0,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config" )  
config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"141.0.154.220\":  $spokes_ipsec_tun1|g" <<< "$config" )

config=$(sed "s|\"{{ vti_interfaces }}\"|\"{{ tun0_vti }}\": $spokes_vti0,\n\"{{ vti_interfaces }}\"|g" <<< "$config" )  
config=$(sed "s|\"{{ vti_interfaces }}\"|      \"{{ tun1_vti }}\": $spokes_vti1|g" <<< "$config" )  

config=$(sed "s|\"{{ bgp_neighbors }}\"|\"169.254.{{ local_octetid }}.1\": $spokes_bgp_neighbor0,\n\"{{ bgp_neighbors }}\"|g" <<< "$config" )  
config=$(sed "s|\"{{ bgp_neighbors }}\"|          \"169.254.{{ local_octetid }}.5\": $spokes_bgp_neighbor1|g" <<< "$config" )

# Get the total number of rows in the CSV file
total_rows=$(( $(wc -l < "$csv_file") - 1 ))
printf "#  %-30s  #\n" "Records found: $total_rows"

row_number=1
# Process each row of the CSV file within a subshell to ensure changes to $config persist
while IFS=, read -r -a row; do
    echo "####################################"
    # Identify the Site we are working with
    local_site=$(echo "${row}" | cut -d',' -f1 | tr -d '"')

    printf "#  %-30s  #\n" "             $local_site"


    # Process global variables
    tempconfig=$(printf "$config" | \
        sed "s/{{ domain_name }}/$domain_name/g" | \
        sed "s/{{ syslog_server }}/$syslog_server/g" | \
        sed "s/{{ support }}/$support/g"
    )
    
    # Process only Local_Subnets
    local_subnets=$(sed 's/"//g' <<< "${row[2]}")
    echo "$local_subnets"
    # Replace all occurrences of '{{ local_subnets }}' with the formatted list of subnets
    tempconfig=$(sed "s|\"{{ local_subnets }}\"|\"$(echo "$local_subnets" | sed 's/ /", "/g')\"|g" <<< "$tempconfig")

    # Process CSV variables
    IFS=, read -r -a values <<< "$row"
    # Assign values to variables dynamically using the columns
    for ((i = 0; i < ${#columns[@]}; i++)); do
        placeholder="${columns[i]}"
        value=$(sed 's/"//g' <<< "${row[$i]}")
        #echo "${columns[i]} = $value"
        # Perform substitution using sed
        tempconfig=$(sed "s|{{ "${columns[i]}" }}|$value|g" <<< "$tempconfig")
    done
     local_site=$(sed 's/"//g' <<< "${local_site}")
    # Output JSON file
    echo "Output: ${output_path}/${local_site}.config.gateway.json"
    printf "$tempconfig" > "${output_path}/${local_site}.config.gateway.json"

    # Increment the row number
    ((row_number++))

    echo "####################################"
done < <(tail -n +2 "$csv_file")
echo "####################################"
echo "#               FINISH             #"    
echo "####################################"