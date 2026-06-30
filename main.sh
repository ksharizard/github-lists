#!/bin/bash

all_stars_file=$(mktemp)
in_lists_file=$(mktemp)

trap 'rm "$all_stars_file" "$in_lists_file"' EXIT

error() { echo -e "\033[31m$1\033[0m"; }
info() { echo -e "\033[34m$1\033[0m"; }
success() { echo -e "\033[32m$1\033[0m"; }
warn() { echo -e "\033[33m$1\033[0m"; }

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

info "Fetching ALL stars (Takes some time if a lot of stars)"
gh api /user/starred --paginate --jq '.[].html_url' >>$all_stars_file
success "Found $(wc -l <"$all_stars_file") total stars."

info "Finding stars in GitHub Lists"
lists=$(gh api graphql -f query='{
    viewer {
        lists(first: 100) {
            nodes {
                name
                items(first: 100) {
                    nodes {
                        ... on Repository {
                            url
                        }
                    }
                }
            }
        }
    }
}')
echo "$lists" | jq -r '.data.viewer.lists.nodes[] | "\(.name):::\(.items.nodes[].url)"' >"$in_lists_file"

if [[ -s "$in_lists_file" ]]; then
    # Extract unique list names in their original order
    awk -F':::' '!seen[$1]++ {print $1}' "$in_lists_file" | while IFS= read -r list_name; do
        info "\n[$list_name]"
        # Filter and format repos for the current list
        awk -F':::' -v list="$list_name" '$1 == list {print $2}' "$in_lists_file"
    done
else
    echo "No repositories found in selected lists."
fi

info "\n----------------------------------"
info "REPOS STARRED BUT NOT IN ANY LIST:"
info "----------------------------------"

# Sort and deduplicate the files
sort -u "$all_stars_file" -o "$all_stars_file"
awk -F':::' '{print $2}' "$in_lists_file" | sort -u -o "$in_lists_file"

# Show items in 'all_stars' that are NOT in 'in_lists'
results=$(comm -23 "$all_stars_file" "$in_lists_file")

if [[ -z "$results" ]]; then
    info "Everything is organized! No unlisted stars found."
else
    echo "$results"
fi
