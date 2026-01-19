#!/bin/bash

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed."
    exit 1
fi

read -p "Enter GitHub username: " username
if [[ -z "$username" ]]; then exit 1; fi

all_stars_file=$(mktemp)
in_lists_file=$(mktemp)

echo "1. Fetching ALL stars"
page=1
while true; do
    echo -ne "Fetching API page $page...\r"

    response=$(curl -sH "Accept: application/vnd.github.v3.star+json" \
        "https://api.github.com/users/$username/starred?page=$page&per_page=100")

    # Use jq to count elements in the array
    count=$(echo "$response" | jq '. | length' 2>/dev/null)

    # If count is 0, we've reached the end
    if [[ "$count" -le 0 ]] || [[ -z "$count" ]]; then
        break
    fi

    echo "$response" | jq -r '.[].repo.full_name' >> "$all_stars_file"

    ((page++))
    sleep 0.2
done
echo -e "\nFound $(wc -l < "$all_stars_file") total stars."

echo "2. Finding your GitHub Lists..."
list_links=$(curl -sL -A "Mozilla/5.0" "https://github.com/$username?tab=stars" | grep "stars/$username/lists/")
mapfile -t lists < <(echo "$list_links" | awk -F'[/"]' '{print $(NF-1)}' | sort -u)

if [ ${#lists[@]} -eq 0 ]; then
    echo "No lists found."
else
    echo "Found ${#lists[@]} lists: ${lists[*]}"
fi

# --- 3. Fetch repos inside lists via Scraping ---
extract_from_html() {
    grep -oP 'href="/[^/"]+/[^/"]+"' | \
    sed 's/href="\///;s/"//' | \
    grep -vE "^(stars|site|settings|orgs|contact|about|customer-stories|topics|collections|trending|events|marketplace|pricing|exploring|features|security|login|join|notifications|search|dashboard|projects|pulls|issues)/"
}

for list_name in "${lists[@]}"; do
    page=1
    while true; do
        echo -ne "Scraping list [$list_name] page $page...\r"
        url="https://github.com/stars/$username/lists/$list_name?page=$page"
        content=$(curl -sL -A "Mozilla/5.0" "$url")
        repos=$(echo "$content" | extract_from_html)

        if [[ -z "$repos" ]]; then break; fi

        echo "$repos" >> "$in_lists_file"
        ((page++))
        sleep 0.5
    done
done

# --- 4. Compare ---
echo -e "\n4. Comparing results..."
echo "------------------------------------------------"
echo "REPOS STARRED BUT NOT IN ANY LIST:"
echo "------------------------------------------------"

sort -u "$all_stars_file" -o "$all_stars_file"
sort -u "$in_lists_file" -o "$in_lists_file"

# Show items in 'all_stars' that are NOT in 'in_lists'
results=$(comm -23 "$all_stars_file" "$in_lists_file" | sed 's|^|https://github.com/|')

if [[ -z "$results" ]]; then
    echo "Everything is organized! No unlisted stars found."
else
    echo "$results"
fi

# Cleanup
rm "$all_stars_file" "$in_lists_file"
