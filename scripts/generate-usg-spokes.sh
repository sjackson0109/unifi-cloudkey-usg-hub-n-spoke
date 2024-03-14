#!/bin/bash
# Purpose: Loop through a CSV data file and several nested JSON files to build a new Unifi config file (config.gateway.json).
# Fundamentally, automate the entire configuration for a 'SPOKES' of a Hub-n-Spoke network design.
# Author: Simon Jackson / @sjackson0109
# Created: 07/03/2024
# Updated: 11/03/2024

# Define template folder, output path, and other global variables
template_folder="/root/templates/usg"
csv_file="/root/config/wheel.csv"   # All fields should be encapsulated in quotes, comma-separated
output_folder="/root/generated"
support="networking@company.com"
domain_name="company.com"
syslog_server="syslog.company.com"

# Read the spoke JSON template files
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
printf "#  %-30s  #\n" "${output_folder}/wheel.csv"

# Process the spoke CSV file
echo "# Processing file:                 #"
config="$spokes_main"

# Escape special characters and remove line feeds and quotes for ike_groups, esp_groups, ipsec_tunnels, and bgp_neighbors sections
spokes_ike_groups=$(tr -d '\n' < "$spokes_ike_groups" | sed 's/"/\\"/g')
spokes_esp_groups=$(tr -d '\n' < "$spokes_esp_groups" | sed 's/"/\\"/g')
spokes_ipsec_tun0=$(tr -d '\n' < "$spokes_ipsec_tun0" | sed 's/"/\\"/g')
spokes_ipsec_tun1=$(tr -d '\n' < "$spokes_ipsec_tun1" | sed 's/"/\\"/g')
spokes_vti0=$(tr -d '\n' < "$spokes_vti0" | sed 's/"/\\"/g')
spokes_vti1=$(tr -d '\n' < "$spokes_vti1" | sed 's/"/\\"/g')
spokes_bgp_neighbor0=$(tr -d '\n' < "$spokes_bgp_neighbor0" | sed 's/"/\\"/g')
spokes_bgp_neighbor1=$(tr -d '\n' < "$spokes_bgp_neighbor1" | sed 's/"/\\"/g')

# Substitute ike_groups, esp_groups, ipsec_tunnels, and bgp_neighbors sections
config=$(sed "s|\"{{ ike_groups }}\"|$spokes_ike_groups|g" <<< "$config" )
config=$(sed "s|\"{{ esp_groups }}\"|$spokes_esp_groups|g" <<< "$config" )
config=$(sed "s|\"{{ ipsec_tunnels }}\"|\"{{ tun0_peer }}\": $spokes_ipsec_tun0,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config" )  
config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"{{ tun1_peer }}\": $spokes_ipsec_tun1|g" <<< "$config" )

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
    local_site=$(echo "${row[0]}" | tr -d '"')
    printf "#  %-30s  #\n" "             $local_site"

    # Process global variables
    tempconfig=$(echo "$config" | \
        sed "s/{{ domain_name }}/$domain_name/g" | \
        sed "s/{{ syslog_server }}/$syslog_server/g" | \
        sed "s/{{ support }}/$support/g"
    )
    
    # Process only Local_Subnets
    local_subnets=$(sed 's/"//g' <<< "${row[2]}")
    # Replace all occurrences of '{{ local_subnets }}' with the formatted list of subnets
    tempconfig=$(sed "s|\"{{ local_subnets }}\"|\"$(echo "$local_subnets" | sed 's/ /", "/g')\"|g" <<< "$tempconfig")

    # Process CSV variables
    for ((i = 0; i < ${#columns[@]}; i++)); do
        value="${row[i]}"
        # Remove double quotes from the value
        value=$(sed 's/"//g' <<< "$value")
        # Perform substitution using sed
        tempconfig=$(sed "s|{{ ${columns[i]} }}|$value|g" <<< "$tempconfig")
    done

    # Output JSON file
    echo "Output: ${output_folder}/spoke-${local_site}.json"
    echo "$tempconfig" > "${output_folder}/spoke-${local_site}.json"

    # Increment the row number
    ((row_number++))

    echo "####################################"
done < <(tail -n +2 "$csv_file")

echo "####################################"
echo "#               FINISH             #"    
echo "####################################"