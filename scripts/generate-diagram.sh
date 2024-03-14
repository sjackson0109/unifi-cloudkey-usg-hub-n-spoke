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
tail -n +2 "$csv_file" | sed 's/"//g' | while IFS=',' read -r local_site _ local_subnets _ _ _ _ _ remote_site _; do
    # Replace hyphens with underscores for Mermaid compatibility
    local_site=$(echo "$local_site" | tr '-' '_')
    remote_site=$(echo "$remote_site" | tr '-' '_')

    # Increment counter
    ((counter++))

    # Determine the direction of the connection based on the counter
    if ((counter % 2 == 0)); then
        # Even line
        echo -e "    $local_site -->|VPN| $remote_site" >> "$output_file"
    else
        # Odd line
        echo -e "    $remote_site -->|VPN| $local_site" >> "$output_file"
    fi
done

# Output the closing part of the Mermaid diagram to the output file
echo "\`\`\`" >> "$output_file"