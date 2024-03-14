#!/bin/bash
# Purpose: Generate a Mermaid Diagram from the wheel.csv file.
# Author: Simon Jackson / @sjackson0109
# Created: 11/03/2024
# Updated: 11/03/2024

# Define the path to the CSV file
csv_file="/root/config/wheel.csv"
output_file="/root/generated/diagram.md"

# Output the initial part of the Mermaid diagram to the output file
echo "\`\`\`mermaid" > "$output_file"
echo "graph LR" >> "$output_file"

# Read the CSV file line by line, removing encapsulated quotes
counter=0
tail -n +2 "$csv_file" | sed 's/"//g' | while IFS=',' read -r local_site _ local_subnets _ _ _ _ remote_site _; do
    # Replace hyphens with underscores for Mermaid compatibility
    local_site=$(echo "$local_site" | tr '-' '_')
    remote_site=$(echo "$remote_site" | tr '-' '_')

    # Increment counter
    ((counter++))

    # Determine the direction of the connection based on the counter
    if ((counter % 2 == 0)); then
        # Even line
        echo -e "    HUB -->|VPN| $remote_site" >> "$output_file"
    else
        # Odd line
        echo -e "    $remote_site -->|VPN| HUB" >> "$output_file"
    fi
done

# Output the closing part of the Mermaid diagram to the output file
echo "\`\`\`\n\n" > "$output_file"


# Output the initial part of the Mermaid diagram to the output file
echo "\`\`\`mermaid" > "$output_file"
echo "flowchart LR" >> "$output_file"
echo "    subgraph HUB[\"HUB\"]" >> "$output_file"
echo "        hub_wan[\"wan1.hub.company.com\"]" >> "$output_file"
echo "        subgraph A[\"FIREWALL\"]" >> "$output_file"
echo "            remote_site[\"HUB-FW-01\"]" >> "$output_file"
echo "        end" >> "$output_file"
echo "    end" >> "$output_file"
echo "    subgraph SPOKE[\"SPOKE\"]" >> "$output_file"
echo "        subgraph B[\"FIREWALL\"]" >> "$output_file"
echo "            local_site[\"local_site\"]" >> "$output_file"
echo "        end" >> "$output_file"
echo "        remote_wan[\"DHCP\"]" >> "$output_file"
echo "    end" >> "$output_file"

# Read the CSV file line by line, removing encapsulated quotes
tail -n +2 "$csv_file" | sed 's/"//g' | while IFS=',' read -r local_site _ local_subnets _ _ _ _ remote_site _; do
    # Replace hyphens with underscores for Mermaid compatibility
    local_site=$(echo "$local_site" | tr '-' '_')
    remote_site=$(echo "$remote_site" | tr '-' '_')

    # Output the connection lines to the output file
    echo "    remote_site === hub_wan" >> "$output_file"
    echo "    remote_wan === local_site" >> "$output_file"
    echo "    hub_wan -.- vpn.tun0 -.- remote_wan" >> "$output_file"
    echo "    hub_wan -.- vpn.tun1 -.- remote_wan" >> "$output_file"
done

# Output the closing part of the Mermaid diagram to the output file
echo "\`\`\`" >> "$output_file"