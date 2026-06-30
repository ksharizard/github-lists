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
gh api /user/starred --paginate --jq '.[].full_name' >> $all_stars_file
success "Found $(wc -l < "$all_stars_file") total stars."

info "Finding stars in GitHub Lists"
lists=$(gh api graphql -F "login=${username}" -f query='query($login: String!) {
  user(login: $login) {
    lists {
      nodes {
        name
        items {
          nodes {
            ... on Repository {
              nameWithOwner
            }
          }
        }
      }
    }
  }
}')
echo "$lists" | jq -r '.data.user.lists.nodes[] | "\(.name):::\(.items.nodes[].nameWithOwner)"' > "$in_lists_file"

if [[ -s "$in_lists_file" ]]; then
    declare -A seen_lists
    declare -a list_order

    while IFS=':::' read -r list_name repo; do
        if [[ -z "${seen_lists[$list_name]}" ]]; then
            list_order+=("$list_name")
            seen_lists[$list_name]=1
        fi
    done < "$in_lists_file"

    # Output grouped by list
    for list_name in "${list_order[@]}"; do
        info "\n[$list_name]"
        grep "^${list_name}:::" "$in_lists_file" | cut -d':' -f4- | sed 's|^|https://github.com/|'
    done
else
    echo "No repositories found in selected lists."
fi

sort -u "$all_stars_file" -o "$all_stars_file"
cut -d':' -f4- "$in_lists_file" | sort -u -o "$in_lists_file"

info "\n----------------------------------"
info "REPOS STARRED BUT NOT IN ANY LIST:"
info "----------------------------------"

# Show items in 'all_stars' that are NOT in 'in_lists'
results=$(comm -23 "$all_stars_file" "$in_lists_file" | sed 's|^|https://github.com/|')

if [[ -z "$results" ]]; then
    info "Everything is organized! No unlisted stars found."
else
    echo "$results"
fi
