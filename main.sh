#!/bin/bash

all_stars_file=$(mktemp)
in_lists_file=$(mktemp)
readonly COOKIE_FILE="cookie.txt"

trap 'rm "$all_stars_file" "$in_lists_file"' EXIT

error() { echo -e "\033[31m$1\033[0m"; }
info() { echo -e "\033[34m$1\033[0m"; }
success() { echo -e "\033[32m$1\033[0m"; }
warn() { echo -e "\033[33m$1\033[0m"; }

select_multiple_lists() {
    local selected=()
    local input

    read -p "Enter your selection: " input

    if [[ "$input" == "all" ]]; then
        selected=("${lists[@]}")
    else
        # Parse space-separated numbers
        for num in $input; do
            if [[ $num -ge 1 && $num -le ${#lists[@]} ]]; then
                selected+=("${lists[$((num - 1))]}")
            else
                echo "Invalid selection: $num"
            fi
        done
    fi

    if [[ ${#selected[@]} -eq 0 ]]; then
        echo "No valid selections made."
        return 1
    fi

    echo "${selected[@]}"
}

# Ask for cookie
prompt_for_cookie() {
    echo "Check README for cookie instructions."
    read -p "Please paste your full GitHub 'Cookie' header string here: " cookie

    if [[ -z "$cookie" ]]; then
        error "Error: No cookie string entered. Exiting."
        exit 1
    fi

    echo "Cookie: $cookie" > "$COOKIE_FILE"
    chmod 600 "$COOKIE_FILE"
    success "Cookie saved."
}

# Test to see if cookie is expired or not
validate_cookie() {
    local test_url="https://github.com/settings/profile"
    local response

    if [[ ! -s "$COOKIE_FILE" ]]; then
        return 1 # No cookie file
    fi

    body=$(curl -sL -A "Mozilla/5.0" -H @"$COOKIE_FILE" $test_url)

    # Check for signs of authentication failure
    if [[ "$body" =~ "Sign in to GitHub" ]] || \
       [[ "$body" =~ "login?return_to" ]] || \
       [[ "$body" =~ "class=\"auth-form-body\"" ]]; then
        return 1  # Cookie expired/invalid
    fi

    return 0  # Cookie is valid
}

extract_from_html() {
    grep -oP 'href="/[^/"]+/[^/"]+"' | \
    sed 's/href="\///;s/"//' | \
    grep -vE "^(stars|site|settings|orgs|contact|about|customer-stories|topics|collections|trending|events|marketplace|pricing|exploring|features|security|login|join|notifications|search|dashboard|projects|pulls|issues|sponsors|sessions)/"
}

# Check for gh
if ! command -v gh &> /dev/null; then
    error "Error: 'gh' is not installed."
    exit 1
fi


# Get program selection
read -p "Enter 1 for getting stars in lists or 2 for unlisted stars: " option
if [[ ! $option =~ ^[12]$ ]]; then
    error "Please choose 1 or 2."
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
    if [[ -s "$COOKIE_FILE" ]]; then
        info "Existing 'cookie.txt' found. Reading cookie from file."
        if ! validate_cookie; then
            warn "Cookie appears expired or invalid."
            read -p "Do you want to enter a new cookie? (y/n): " refresh
            if [[ "$refresh" == "y" ]]; then
                rm -f "$COOKIE_FILE"
                prompt_for_cookie
            else
                error "Cannot proceed without valid cookie. Exiting."
                exit 1
            fi
        else
            success "Cookie validated successfully."
        fi
    else
        prompt_for_cookie
    fi
fi


info "Finding your GitHub Lists"
if [[ $private_option == "y" ]]; then
    list_links=$(curl -sL -A "Mozilla/5.0" -H @"$COOKIE_FILE" "https://github.com/$username?tab=stars" | grep "$username/lists/")
else
    list_links=$(curl -sL -A "Mozilla/5.0" "https://github.com/$username?tab=stars" | grep "$username/lists/")
fi
mapfile -t lists < <(echo "$list_links" | awk -F'[/"]' '{print $(NF-1)}' | sort -u)
if [ ${#lists[@]} -eq 0 ]; then
    error "No lists found."
else
    success "Found ${#lists[@]} lists: ${lists[*]}"
fi


if [[ $option == 1 ]]; then
    echo "Please select lists to query (enter numbers separated by spaces, or 'all' for all lists):"
    # Display available lists
    for i in "${!lists[@]}"; do
        echo "$((i + 1)). ${lists[$i]}"
    done

    # Get selections
    selected=$(select_multiple_lists)
    if [[ $? -eq 0 ]]; then
        read -ra selected_lists <<< "$selected"
        echo "You selected: ${selected_lists[*]}"
    fi
elif [[ $option == 2 ]]; then
    info "Fetching ALL stars (Takes some time if a lot of stars)"
    gh api /user/starred --paginate --jq '.[].full_name' >> $all_stars_file
    success "Found $(wc -l < "$all_stars_file") total stars."
    selected_lists=("${lists[@]}")
fi

for list_name in "${selected_lists[@]}"; do
    page=1
    info "\nScraping list [$list_name]"
    while true; do
        echo -ne "page $page\r"
        url="https://github.com/stars/$username/lists/$list_name?page=$page"
        if [[ $private_option == "y" ]]; then
            content=$(curl -sL -A "Mozilla/5.0" -H @"$COOKIE_FILE" "$url")
        elif [[ $private_option == "n" ]]; then
            content=$(curl -sL -A "Mozilla/5.0" "$url")
        fi
        repos=$(echo "$content" | extract_from_html)

        if [[ -z "$repos" ]]; then break; fi

        echo "$repos" | while read -r repo; do
            [[ -n "$repo" ]] && echo "${list_name}:::${repo}"
        done >> "$in_lists_file"

        ((page++))
        sleep 1
    done
done


if [[ $option == 1 ]]; then
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
fi

if [[ $option == 2 ]]; then
    sort -u "$all_stars_file" -o "$all_stars_file"
    cut -d':' -f4- "$in_lists_file" | sort -u -o "$in_lists_file"

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
fi

