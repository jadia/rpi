#!/bin/bash

# Set variables
backup_dir="/path/to/backup/directory"
ghost_container="ghost"
db_container="db"
db_user="root"
db_password="password"
db_name="ghost"

# Define functions
function backup() {
    # Create backup directory if it doesn't exist
    mkdir -p $backup_dir

    # Create backup filename with timestamp
    backup_file="$backup_dir/ghost_backup_$(date +%Y%m%d-%H%M%S).tar.gz"

    # Backup Ghost data volume
    docker run --rm --volumes-from $ghost_container -v $backup_dir:/backup alpine \
        tar czf /backup/ghost_data.tar.gz /var/lib/ghost/content

    # Backup database
    docker exec $db_container sh -c "exec mysqldump --single-transaction -u $db_user -p$db_password $db_name" \
        > $backup_dir/ghost_database.sql

    # Compress backup files
    tar czf $backup_file $backup_dir/*

    echo "Backup complete: $backup_file"
}

function restore() {
    # Prompt user for backup file to restore
    read -p "Enter backup file path: " backup_file

    # Extract backup files
    tar xzf $backup_file -C $backup_dir

    # Restore Ghost data volume
    docker run --rm --volumes-from $ghost_container -v $backup_dir:/backup alpine \
        sh -c "cd /var/lib/ghost/content && tar xzf /backup/ghost_data.tar.gz"

    # Restore database
    docker exec -i $db_container sh -c "exec mysql -u $db_user -p$db_password $db_name" \
        < $backup_dir/ghost_database.sql

    echo "Restore complete"
}

# Display menu
echo "Ghost Backup and Restore Script"
echo "-------------------------------"
echo "1. Backup"
echo "2. Restore"
echo "3. Exit"

# Get user input
read -p "Select an option: " option

# Call corresponding function based on user input
case $option in
    1)
        backup
        ;;
    2)
        restore
        ;;
    3)
        exit 0
        ;;
    *)
        echo "Invalid option"
        exit 1
        ;;
esac

exit 0
