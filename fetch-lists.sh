#!/bin/bash

trap 'echo -e "\n\nInterrupted by user." >&2; exit 130' INT

get_private_lists_option() {
    local private_option
    read -p "Do you want to fetch private lists? (y/n): " private_option
    if [[ $private_option =~ ^[Yy]$ ]]; then
        echo "$private_option"
    else
        echo "Please answer 'y' or 'n'."
        exit 1
    fi
}


main() {
    while getopts ":u:" opt; do
        case $opt in
            u) username="$OPTARG" ;;
            *) echo "Usage: $0 -f <file> -o <output>"; exit 1 ;;
        esac
    done

    if [[ ! -n $username ]]; then
        username=$(./helper/get-username.sh)
    fi
    private_option=$(get_private_lists_option)

    if [[ $private_option == "y" ]]; then
        ./helper/get-cookie.sh
        list_links=$(curl -sL -A "Mozilla/5.0" -H @cookie.txt "https://github.com/$username?tab=stars" | grep "$username/lists/")
    else
        list_links=$(curl -sL -A "Mozilla/5.0" "https://github.com/$username?tab=stars" | grep "$username/lists/")
    fi
    echo "$list_links" | awk -F'[/"]' '{print $(NF-1)}' | sort -u
}
main "$@"
