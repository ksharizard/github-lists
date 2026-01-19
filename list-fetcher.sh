#!/bin/bash

read -p "Enter GitHub username: " username

if [[ -z "$username" ]]; then
    echo "Username cannot be empty."
    exit 1
fi

echo "Fetching lists for $username..."
# 1. Get the HTML and extract the list names
# Using -L to follow redirects and a User-Agent to ensure standard HTML
list_links=$(curl -sL -A "Mozilla/5.0" "https://github.com/$username?tab=stars" | grep "ksharizard/lists")

mapfile -t lists < <(echo "$list_links" | awk -F'[/"]' '{print $(NF-1)}' | sort -u)

if [ ${#lists[@]} -eq 0 ]; then
    echo "No lists found for user: $username"
    exit 1
fi

# 2. Ask the user to select a list
echo ""
echo "Please select a list to query:"
select list_name in "${lists[@]}"; do
    if [ -n "$list_name" ]; then
        echo "You selected: $list_name"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# 3. Paginate through the selected list
page=1
all_repos=()

echo "Starting query for list: $list_name"
echo "-----------------------------------"

while true; do
    echo "Fetching page $page..."
    page_source=$(curl -sL -A "Mozilla/5.0" "https://github.com/stars/$username/lists/$list_name?page=$page")

    # Extract repo links.
    # We look for links in the format /user/repo inside <h3> tags
    # We exclude common links like /stars, /settings, /orgs, etc.
    current_page_repos=$(echo "$page_source" | \
        grep -oP 'href="/[^/"]+/[^/"]+"' | \
        sed 's/href="//;s/"//' | \
        grep -vE "^/(stars|site|settings|orgs|contact|about|customer-stories|topics|collections|trending|events|marketplace|pricing|exploring|features|security|login|join|notifications|search|dashboard)/" | \
        sed 's|^/|https://github.com/|' | \
        sort -u)

    # If no repos are found on this page, stop the loop
    if [[ -z "$current_page_repos" ]]; then
        echo "No more projects found. Reached the end."
        break
    fi

    # Display found repos for this page
    echo "Found on page $page:"
    echo "$current_page_repos"
    echo "-----------------------------------"

    # Increment page number
    ((page++))

    # Optional: Brief sleep to avoid hitting rate limits
    sleep 1
done

echo "Finished querying $list_name."
