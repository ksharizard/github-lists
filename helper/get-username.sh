#!/bin/bash

get_username() {
    local username
    read -p "Enter GitHub username: " username
    if [[ ! -z "$username" ]]; then
        echo "$username"
    else
        echo "Username cannot be empty."
        exit 1
    fi
}

main() {
    get_username
}
main "$@"
