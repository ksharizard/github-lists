# github-lists
Script that provide utilities to organise and interact with your GitHub lists.

## Requirements
- `github-cli`: Gets user's stars

## Features
- **Fetch lists**: Retrieves lists (public and private) of a user and shows the stars in the lists.
- **Fetch unlisted stars**: Goes through a user's stars and lists' stars, then compares them to find stars which are not in any list.

## Cookie
1) Open [github.com](https://github.com) (Be logged in)
2) Open **Web Developer Tools** (Press F12 or Ctrl+Shift+I/Cmd+Option+I)
3) Switch to the **Network** tab and reload GitHub
4) In the request list, filter by typing `github.com` or select **Doc**/**HTML**
5) Click the first request (usually `github.com` or your username page)
6) In the right panel, select the **Headers** tab
7) Scroll down to the **Request Headers** section
8) Find the `Cookie:` header line
9) **Copy only the value** (not the `Cookie:` label)
10) Paste the copied string when the script prompts

Make sure the pasted cookie looks like the following:
```
user_session=abc123...; _gh_sess=xyz789...; logged_in=yes; dotcom_user=yourname
```
