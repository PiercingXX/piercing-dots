#!/bin/bash
# GitHub.com/PiercingXX

# User Management Script

while true; do
    clear
    action=$(gum choose --header="User Management" "Add User" "Remove User" "Change Password" "Back")
    case "$action" in
        "Add User")
            read -p "Enter new username: " username
            sudo useradd -m "$username" && echo "User $username added."
            ;;
        "Remove User")
            read -p "Enter username to remove: " username
            sudo userdel -r "$username" && echo "User $username removed."
            ;;
        "Change Password")
            read -p "Enter username: " username
            sudo passwd "$username"
            ;;
        "Back"|"")
            break
            ;;
    esac
    echo "Press Enter to continue..."
    read
    clear
    # Loop back to menu
    continue
    break
    done
