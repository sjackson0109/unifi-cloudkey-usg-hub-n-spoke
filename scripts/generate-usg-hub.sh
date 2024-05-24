#!/bin/bash
# Purpose: Loop through a CSV data file and several nested JSON files to build a new Unifi config file (config.gateway.json).
# Fundamentally, automate the entire configuration for a `HUB` of a Hub-n-Spoke network design.
# Author: Simon Jackson / @sjackson0109
# Code: https://github.com/sjackson0109/unifi-cloudkey-usg-hub-n-spoke
# Created: 07/03/2024
# Updated: 24/05/2024

# Define template folder, output path, and other global variables
template_folder="/root/templates/usg"
csv_file="/root/config/wheel.csv"   # All fields should be encapsulated in quotes, comma-separated
output_folder="/root/generated"
support="networking@company.com"
domain_name="company.com"
syslog_server="syslog.company.com"
controller_vpn_address="unifi.company.local"
hub_sitename="HUB"     # UPDATE THE NAME OF YOUR HUB SITE HERE

# Read the hub JSON template files
hub_main=$(<"${template_folder}/hub.json")
hub_ike_groups=$(<"${template_folder}/hub-ike-groups.json")
hub_esp_groups=$(<"${template_folder}/hub-esp-groups.json")
hub_ipsec_tun0=$(<"${template_folder}/hub-ipsec-tun0.json")
hub_ipsec_tun1=$(<"${template_folder}/hub-ipsec-tun1.json")
hub_vti0=$(<"${template_folder}/hub-vti0.json")
hub_vti1=$(<"${template_folder}/hub-vti1.json")
hub_bgp_neighbor0=$(<"${template_folder}/hub-bgp-neighor0.json")
hub_bgp_neighbor1=$(<"${template_folder}/hub-bgp-neighor1.json")

echo "###################################"
echo "#               START             #"
echo "###################################"

# Read the header row of the CSV file to get the column names
IFS=, read -r -a columns < <(sed 's/"//g' <<< "$(head -n 1 "$csv_file")")
echo "#          CSV IMPORTED            #"
printf "#  %-30s  #\n" "${output_folder}/wheel.csv"

# Process the hub CSV file
echo "# Processing file:                 #"
config="$hub_main"

# Escape special characters and remove line feeds and quotes for ike_groups, esp_groups, and ipsec_tunnels sections
hub_ike_groups=$(printf "$hub_ike_groups" | tr -d '\n' | sed 's/"/\\"/g')
hub_esp_groups=$(printf "$hub_esp_groups" | tr -d '\n' | sed 's/"/\\"/g')
hub_ipsec_tun0=$(printf "$hub_ipsec_tun0" | tr -d '\n' | sed 's/"/\\"/g')
hub_ipsec_tun1=$(printf "$hub_ipsec_tun1" | tr -d '\n' | sed 's/"/\\"/g')
hub_vti0=$(printf "$hub_vti0" | tr -d '\n' | sed 's/"/\\"/g')
hub_vti1=$(printf "$hub_vti1" | tr -d '\n' | sed 's/"/\\"/g')
hub_bgp_neighbor0=$(printf "$hub_bgp_neighbor0" | tr -d '\n' | sed 's/"/\\"/g')
hub_bgp_neighbor1=$(printf "$hub_bgp_neighbor1" | tr -d '\n' | sed 's/"/\\"/g')


# Substitute ike_groups and esp_groups sections (ipsec_tunnels section is performed iteratively inside the while loop)
config=$(sed "s|\"{{ ike_groups }}\"|$hub_ike_groups|g" <<< "$config")
config=$(sed "s|\"{{ esp_groups }}\"|$hub_esp_groups|g" <<< "$config")

# Get the total number of rows in the CSV file
total_rows=$(( $(wc -l < "$csv_file") - 1 ))
printf "#  %-30s  #\n" "Records found: $total_rows"

row_number=1
# Process each row of the CSV file within a subshell to ensure changes to $config persist
while IFS=, read -ra row; do
    echo "###################################"

    # Identify the Site we are working with
    local_site=$(echo "${row}" | cut -d',' -f1 | tr -d '"')
    printf "#  %-30s  #\n" "             $local_site"
    echo "------------------------------------"

    # Process ipsec_tunnels for each row in the sheet
    if [ "$total_rows" -ne "1" ] && [ "$row_number" -eq "1" ]; then
        config=$(sed "s|\"{{ ipsec_tunnels }}\"|\"${local_site}.tun0\": $hub_ipsec_tun0,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config")
        config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"${local_site}.tun1\": $hub_ipsec_tun1,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config")
    else
        if [ "$row_number" -ne "$total_rows" ]; then
            config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"${local_site}.tun0\": $hub_ipsec_tun0,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"${local_site}.tun1\": $hub_ipsec_tun1,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config")
        else # Processing the last record, different formatting
            config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"${local_site}.tun0\": $hub_ipsec_tun0,\n\"{{ ipsec_tunnels }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ ipsec_tunnels }}\"|          \"${local_site}.tun1\": $hub_ipsec_tun1|g" <<< "$config")
        fi
    fi

    # Process vti_interfaces for each row in the sheet
    if [ "$total_rows" -ne "1" ] && [ "$row_number" -eq "1" ]; then
        config=$(sed "s|\"{{ vti_interfaces }}\"|\"{{ tun0_vti }}\": $hub_vti0,\n\"{{ vti_interfaces }}\"|g" <<< "$config")
        config=$(sed "s|\"{{ vti_interfaces }}\"|      \"{{ tun1_vti }}\": $hub_vti1,\n\"{{ vti_interfaces }}\"|g" <<< "$config")
    else
        if [ "$row_number" -ne "$total_rows" ]; then
            config=$(sed "s|\"{{ vti_interfaces }}\"|      \"{{ tun0_vti }}\": $hub_vti0,\n\"{{ vti_interfaces }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ vti_interfaces }}\"|      \"{{ tun1_vti }}\": $hub_vti1,\n\"{{ vti_interfaces }}\"|g" <<< "$config")
        else # Processing the last record, different formatting
            config=$(sed "s|\"{{ vti_interfaces }}\"|      \"{{ tun0_vti }}\": $hub_vti0,\n\"{{ vti_interfaces }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ vti_interfaces }}\"|      \"{{ tun1_vti }}\": $hub_vti1|g" <<< "$config")
        fi
    fi

    # Process interface_routes for each row in the sheet
    if [ "$total_rows" -ne "1" ] && [ "$row_number" -eq "1" ]; then
        config=$(sed "s|\"{{ interface_routes }}\"|\"169.254.{{ local_octetid }}.0/30\":{ \"next-hop-interface\": \"{{ tun0_vti }}\" },\n\"{{ interface_routes }}\"|g" <<< "$config")
        config=$(sed "s|\"{{ interface_routes }}\"|        \"169.254.{{ local_octetid }}.4/30\":{ \"next-hop-interface\": \"{{ tun1_vti }}\" },\n\"{{ interface_routes }}\"|g" <<< "$config")
    else
        if [ "$row_number" -ne "$total_rows" ]; then
            config=$(sed "s|\"{{ interface_routes }}\"|        \"169.254.{{ local_octetid }}.0/30\":{ \"next-hop-interface\": \"{{ tun0_vti }}\" },\n\"{{ interface_routes }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ interface_routes }}\"|        \"169.254.{{ local_octetid }}.4/30\":{ \"next-hop-interface\": \"{{ tun1_vti }}\" },\n\"{{ interface_routes }}\"|g" <<< "$config")
        else # Processing the last record, different formatting
            config=$(sed "s|\"{{ interface_routes }}\"|        \"169.254.{{ local_octetid }}.0/30\":{ \"next-hop-interface\": \"{{ tun0_vti }}\" },\n\"{{ interface_routes }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ interface_routes }}\"|        \"169.254.{{ local_octetid }}.4/30\":{ \"next-hop-interface\": \"{{ tun1_vti }}\" }|g" <<< "$config")
        fi
    fi

    # Process bgp_neighbors for each row in the sheet
    if [ "$total_rows" -ne "1" ] && [ "$row_number" -eq "1" ]; then
        config=$(sed "s|\"{{ bgp_neighbors }}\"|\"169.254.{{ local_octetid }}.2\": $hub_bgp_neighbor0,\n\"{{ bgp_neighbors }}\"|g" <<< "$config")
        config=$(sed "s|\"{{ bgp_neighbors }}\"|          \"169.254.{{ local_octetid }}.6\": $hub_bgp_neighbor1,\n\"{{ bgp_neighbors }}\"|g" <<< "$config")
    else
        if [ "$row_number" -ne "$total_rows" ]; then
            config=$(sed "s|\"{{ bgp_neighbors }}\"|          \"169.254.{{ local_octetid }}.2\": $hub_bgp_neighbor0,\n\"{{ bgp_neighbors }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ bgp_neighbors }}\"|          \"169.254.{{ local_octetid }}.6\": $hub_bgp_neighbor1,\n\"{{ bgp_neighbors }}\"|g" <<< "$config")
        else # Processing the last record, different formatting
            config=$(sed "s|\"{{ bgp_neighbors }}\"|          \"169.254.{{ local_octetid }}.2\": $hub_bgp_neighbor0,\n\"{{ bgp_neighbors }}\"|g" <<< "$config")
            config=$(sed "s|\"{{ bgp_neighbors }}\"|          \"169.254.{{ local_octetid }}.6\": $hub_bgp_neighbor1|g" <<< "$config")
        fi
    fi

    echo "------------------------------------"

    # Process CSV variables
    for ((i = 0; i < ${#columns[@]}; i++)); do
        value="${row[$i]}"
        # Remove double quotes from the value
        value=$(sed 's/"//g' <<< "$value")
        # Drop newlines
        value=$(echo "$value" | tr -d "\n")
        # Perform substitution using sed
        config=$(sed "s|{{ ${columns[i]} }}|$value|g" <<< "$config")
    done

    # Process global variables
    config=$(printf "$config" | \
        sed "s/{{ hub_sitename }}/$hub_sitename/g" | \
        sed "s/{{ domain_name }}/$domain_name/g" | \
        sed "s/{{ syslog_server }}/$syslog_server/g" | \
        sed "s/{{ controller_vpn_address }}/$controller_vpn_address/g" | \
        sed "s/{{ support }}/$support/g"
    )

    # Increment the row number
    ((row_number++))
done < <(tail -n +2 "$csv_file")

echo "###################################"
# Output JSON file
echo "Output: ${output_folder}/${hub_sitename}.config.gateway.json"
printf "$config" > "${output_folder}/${hub_sitename}.config.gateway.json"
echo "###################################"