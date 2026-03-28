#!/bin/bash

all_stars_file=$(mktemp)
in_lists_file=$(mktemp)
COOKIE_FILE="cookie.txt"

trap 'rm "$all_stars_file" "$in_lists_file"' EXIT

error() {
    echo -e "\033[31m$1\033[0m"
}

success() {
    echo -e "\033[32m$1\033[0m"
}

info() {
    echo -e "\033[34m$1\033[0m"
}

extract_from_html() {
    grep -oP 'href="/[^/"]+/[^/"]+"' | \
    sed 's/href="\///;s/"//' | \
    grep -vE "^(stars|site|settings|orgs|contact|about|customer-stories|topics|collections|trending|events|marketplace|pricing|exploring|features|security|login|join|notifications|search|dashboard|projects|pulls|issues)/"
}


# Check for gh
if ! command -v gh &> /dev/null; then
    error "Error: 'gh' is not installed."
    exit 1
fi


# Get username
read -p "Enter GitHub username: " username
if [[ -z "$username" ]]; then
    error "Username cannot be empty."
    exit 1
fi


# Get private lists option
read -p "Do you want to fetch private lists? (y/n): " private_option
if [[ ! $private_option =~ ^[yn]$ ]]; then
    error "Please answer 'y' or 'n'."
    exit 1
fi


# Get cookie
if [[ $private_option == "y" ]]; then
    if [[ -s "cookie.txt" ]]; then
        info "Existing 'cookie.txt' found. Reading cookie from file."
    else
        echo "Check README for cookie instructions."
        read -p "Please paste your full GitHub 'Cookie' header string here: " cookie

        if [[ -z "$cookie" ]]; then
            error "Error: No cookie string entered. Exiting."
            exit 1
        fi

        echo "Cookie: $cookie" > cookie.txt
        chmod 600 cookie.txt # Set secure permissions (only owner can read/write)

        success "Cookie saved."
    fi
fi


info "Fetching ALL stars (Takes some time if a lot of stars)"
gh api /user/starred --paginate --jq '.[].full_name' >> $all_stars_file
success "Found $(wc -l < "$all_stars_file") total stars."


info "Finding your GitHub Lists"
if [[ $private_option == "y" ]]; then
    list_links=$(curl -sL -A "Mozilla/5.0" -H @cookie.txt "https://github.com/$username?tab=stars" | grep "$username/lists/")
else
    list_links=$(curl -sL -A "Mozilla/5.0" "https://github.com/$username?tab=stars" | grep "$username/lists/")
fi
mapfile -t lists < <(echo "$list_links" | awk -F'[/"]' '{print $(NF-1)}' | sort -u)
if [ ${#lists[@]} -eq 0 ]; then
    error "No lists found."
else
    success "Found ${#lists[@]} lists: ${lists[*]}"
fi


for list_name in "${lists[@]}"; do
    page=1
    info "\nScraping list [$list_name]"
    while true; do
        echo -ne "page $page\r"
        url="https://github.com/stars/$username/lists/$list_name?page=$page"
        content=$(curl -sL -A "Mozilla/5.0" "$url")
        repos=$(echo "$content" | extract_from_html)

        if [[ -z "$repos" ]]; then break; fi

        echo "$repos" >> "$in_lists_file"
        ((page++))
        sleep 1
    done
done


sort -u "$all_stars_file" -o "$all_stars_file"
sort -u "$in_lists_file" -o "$in_lists_file"

echo "----------------------------------"
echo "REPOS STARRED BUT NOT IN ANY LIST:"
echo "----------------------------------"

# Show items in 'all_stars' that are NOT in 'in_lists'
results=$(comm -23 "$all_stars_file" "$in_lists_file" | sed 's|^|https://github.com/|')

if [[ -z "$results" ]]; then
    echo "Everything is organized! No unlisted stars found."
else
    echo "$results"
fi

