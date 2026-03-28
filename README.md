# github-lists
Script that provide utilities to organise and interact with your GitHub lists.

## Requirements
- `github-cli`: Gets user's stars

## Features
- **Fetch lists**: Retrieves lists (public and private) of a user and shows the stars in the lists.
- **Fetch unlisted stars**: Goes through a user's stars and lists' stars, then compares them to find stars which are not in any list.

## Cookie
1) Open github.com (Be logged in)
2) Open **Web Developer Tools** (Press F12)
3) Open **Network** and reload GitHub
4) Select a GET request (HTML type works most of the time)
5) In the headers, scroll down to the Request Headers and find the Cookie header
6) Right click on it and "Copy Value"

