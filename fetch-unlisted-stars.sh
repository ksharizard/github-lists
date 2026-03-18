#!/bin/bash

trap 'echo -e "\n\nInterrupted by user." >&2; exit 130' INT

check_jq() {
    if ! command -v jq &> /dev/null; then
        echo "Error: 'jq' is not installed."
        exit 1
    fi
}

fetch_stars() {
    echo "Fetching ALL stars"
    page=1
    while true; do
        echo -ne "Fetching page $page...\r"

        response=$(curl -sH "Accept: application/vnd.github.v3.star+json" \
            "https://api.github.com/users/$username/starred?page=$page&per_page=100")

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
}


fetch_all_lists(){
    # echo "Finding your GitHub Lists..."
    mapfile -t lists < <(./fetch-lists.sh -u $username)
    if [ ${#lists[@]} -eq 0 ]; then
        echo "No lists found."
    else
        echo "Found ${#lists[@]} lists: ${lists[*]}"
    fi
}


extract_from_html() {
    grep -oP 'href="/[^/"]+/[^/"]+"' | \
    sed 's/href="\///;s/"//' | \
    grep -vE "^(stars|site|settings|orgs|contact|about|customer-stories|topics|collections|trending|events|marketplace|pricing|exploring|features|security|login|join|notifications|search|dashboard|projects|pulls|issues)/"
}


fetch_all_list_stars() {
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
            sleep 1
        done
    done
}


main() {
    username=$(./helper/get-username.sh)

    all_stars_file=$(mktemp)
    in_lists_file=$(mktemp)

    check_jq
    fetch_stars

    fetch_all_lists
    fetch_all_list_stars

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

    # Cleanup
    rm "$all_stars_file" "$in_lists_file"
}
main "$@"
