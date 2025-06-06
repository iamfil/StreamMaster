#!/bin/bash

. /env.sh

user_name="nonRootUser"
group_name="nonRootGroup"

# Directories to create
declare -a dirs=(
    "/config/Cache"
    "/config/Logs"
    "/config/PlayLists/EPG"
    "/config/PlayLists/M3U"
    "/config/HLS"
    "/app/wwwroot"
    "$PGDATA"
    "$BACKUP_DIR"
    "$RESTORE_DIR"
)

# Validate PUID/PGID only if they are set and non-zero
if [ ! -z "$PUID" ]; then
    if [ "$PUID" -eq 0 ]; then
        echo "Running with root user (PUID=0)"
    elif [ "$PUID" -lt 1 ] || [ "$PUID" -gt 65534 ] 2>/dev/null; then
        echo "Invalid PUID: $PUID. Must be between 1 and 65534"
        exit 1
    fi
fi

if [ ! -z "$PGID" ]; then
    if [ "$PGID" -eq 0 ]; then
        echo "Running with root group (PGID=0)"
    elif [ "$PGID" -lt 1 ] || [ "$PGID" -gt 65534 ] 2>/dev/null; then
        echo "Invalid PGID: $PGID. Must be between 1 and 65534"
        exit 1
    fi
fi

if ! echo "{
  \"defaultPort\": $DEFAULT_PORT,
  \"defaultBaseUrl\": \"${BASE_URL}\"
}" >/app/wwwroot/config.json; then
    echo "Failed to create config.json"
    exit 1
fi

# Safe directory creation function
safe_mkdir() {
    local dir="$1"
    mkdir -p "$dir" 2>/dev/null || echo "Failed to create directory $dir"
}

# Safe ownership change function
safe_chown() {
    local owner="$1"
    local path="$2"
    chown "$owner" "$path" 2>/dev/null || echo "Failed to change ownership of $path"
}

# Enable nullglob to handle empty directory cases safely
shopt -s nullglob

moveFilesAndDeleteDir() {
    local source_dir="$1"
    local destination_dir="$2"

    # Check if the source directory exists
    if [ -d "$source_dir" ]; then
        # Ensure the destination directory exists, create if not
        if [ ! -d "$destination_dir" ]; then
            mkdir -p "$destination_dir"
        fi

        # Check if there are any files or directories in source_dir
        local files=("$source_dir"/*)
        if [ -e "${files[0]}" ]; then
            # Move files from source to destination
            if mv "$source_dir"/* "$destination_dir"/ 2>/dev/null; then
                echo "Files moved successfully from $source_dir to $destination_dir."
            else
                echo "Failed to move files from $source_dir to $destination_dir."
                return
            fi
        else
            echo "No files to move from $source_dir."
        fi

        # Remove the source directory
        if rmdir "$source_dir" 2>/dev/null; then
            echo "Source directory $source_dir removed."
        else
            echo "Failed to remove source directory $source_dir. It might not be empty."
        fi
    fi
}

# Function to check for any file ready to be restored in /config/DB/Restore
check_files_ready_for_restore() {
    local file_found=1 # Default to no files found (1 means no files ready)

    # Check if the restore directory exists
    if [ ! -d "$RESTORE_DIR" ]; then
        echo "Restore path does not exist: $RESTORE_DIR"
        return 1
    fi

    # Find files matching the backup pattern
    local files=("$RESTORE_DIR"/backup_*.tar.gz)
    if [ ${#files[@]} -eq 0 ] || [ ! -e "${files[0]}" ]; then
        echo "No backup files found in $RESTORE_DIR."
        return 1
    fi

    # Check each file for size
    for file in "${files[@]}"; do
        if [ -s "$file" ]; then
            echo "File is ready for restore: $(basename "$file")"
            file_found=0 # Set to 0 if a file is found and is not empty
            break
        else
            echo "Found an empty backup file: $(basename "$file")"
        fi
    done

    return $file_found
}

rename_directory() {
    local src="$1"
    local dest="$2"

    # Check if the source directory exists
    if [ ! -d "$src" ]; then
        return 1
    fi

    # Check for case sensitivity and existence of the destination directory
    if [ "$src" = "$dest" ]; then
        return 1
    fi

    # Use temporary destination for atomic move
    local temp_dest="${dest}.tmp"
    if [ -d "$dest" ] || [ -d "$temp_dest" ]; then
        return 1
    fi

    # Perform the rename
    if mv "$src" "$temp_dest" && mv "$temp_dest" "$dest"; then
        echo "Directory renamed successfully from $src to $dest"
    else
        echo "Failed to rename directory from $src to $dest"
        # Cleanup temp directory if move failed
        rm -rf "$temp_dest" 2>/dev/null
        return 1
    fi
}

# PostgreSQL connection parameters
POSTGRES_MAX_ATTEMPTS=${POSTGRES_MAX_ATTEMPTS:-20}
POSTGRES_WAIT_INTERVAL=${POSTGRES_WAIT_INTERVAL:-5}

wait_for_postgres() {
    local host="$1"
    local port="$2"
    local max_attempts="$3"
    local wait_interval="$4"
    local attempt=0

    while [ $attempt -lt "$max_attempts" ]; do
        if pg_isready -h "$host" -p "$port" >/dev/null 2>&1; then
            echo "PostgreSQL is ready on $host:$port"
            return 0
        fi
        attempt=$((attempt + 1))
        echo "Attempt $attempt: PostgreSQL is not yet ready on $host:$port. Retrying in $wait_interval seconds..."
        sleep "$wait_interval"
    done

    echo "Error: PostgreSQL on $host:$port is not ready after $max_attempts attempts."
    return 1
}

# Check if PUID or PGID is set to a non-root value
if [ "$PUID" -ne 0 ]; then
    if getent passwd "$PUID" >/dev/null 2>&1; then
        user_name=$(getent passwd "$PUID" | cut -d: -f1)
    else
        useradd --uid "$PUID" -K UID_MIN=10 --comment "nonRootUser" --shell /bin/bash nonRootUser || {
            echo "Failed to create user with PUID: $PUID"
            exit 1
        }
    fi
fi

if [ "$PGID" -ne 0 ]; then
    if getent group "$PGID" >/dev/null 2>&1; then
        group_name=$(getent group "$PGID" | cut -d: -f1)
    else
        addgroup --gid "$PGID" --force-badname "nonRootGroup" || {
            echo "Failed to create group with PGID: $PGID"
            exit 1
        }
    fi
fi

rm -rf /config/hls

# Create all required directories
for dir in "${dirs[@]}"; do
    if ! safe_mkdir "$dir"; then
        echo "Critical directory creation failed for: $dir"
        exit 1
    fi
done

rename_directory /config/settings /config/Settings
rename_directory /config/backups /config/Backups

# Create trap for temporary file cleanup
trap 'rm -f "$temp_script"' EXIT

# Change ownership of the /app directory
if [ "$PUID" -ne 0 ] || [ "$PGID" -ne 0 ]; then
    # Set ownership for main directories
    if ! safe_chown "${PUID:-0}:${PGID:-0}" "/app"; then
        echo "Critical ownership change failed for: /app"
        exit 1
    fi

    # Handle /config directory permissions
    # Create a temporary script for find -exec
    temp_script=$(mktemp)
    echo '#!/bin/sh' > "$temp_script"
    echo "chown -R ${PUID:-0}:${PGID:-0} \"\$1\"" >> "$temp_script"
    chmod +x "$temp_script"

    find /config -mindepth 1 -maxdepth 1 -type d \
        -not -path '/config/tv-logos' \
        -not -path '/config/DB' \
        -exec "$temp_script" {} \;

    # Handle special directories
    safe_chown "${PUID:-0}:${PGID:-0}" '/config/tv-logos'
    safe_chown "${PUID:-0}:${PGID:-0}" "$BACKUP_DIR"
    safe_chown "${PUID:-0}:${PGID:-0}" "$RESTORE_DIR"
fi

# Set specific permissions for backup/restore directories
if ! chmod 775 "$BACKUP_DIR"; then
    echo "Failed to set permissions on $BACKUP_DIR"
    exit 1
fi
if ! chmod 775 "$RESTORE_DIR"; then
    echo "Failed to set permissions on $RESTORE_DIR"
    exit 1
fi

# Handle PostgreSQL permissions
if [ "$POSTGRES_ISLOCAL" -eq 1 ] && [ "$POSTGRES_SET_PERMS" -eq 1 ]; then
    safe_chown "postgres:postgres" "$PGDATA"
fi

# Pretty printing the configuration
echo "Configuration:"
echo "--------------"
echo "HOST:"
echo "  Default Port: $DEFAULT_PORT"
echo "  Default SSL Port: $DEFAULT_SSL_PORT"
echo "PGADMIN:"
echo "  Platform Type: $PGADMIN_PLATFORM_TYPE"
echo "  Setup Email: $PGADMIN_SETUP_EMAIL"
echo "  Setup Password: ********"
echo "POSTGRES:"
echo "  User: $POSTGRES_USER"
echo "  Password: ********"
echo "  DB Name: $POSTGRES_DB"
echo "  Host: $POSTGRES_HOST"
echo "  Is DB Local: $POSTGRES_ISLOCAL"
echo "  Data Directory: $PGDATA"
echo "  Set Perms: $POSTGRES_SET_PERMS"
echo "OS:"
echo "  User: ${PUID:-0} Group: ${PGID:-0}"
echo "  User: postgres Group: postgres"
echo "  UID: $(id -u postgres) GID: $(id -g postgres)"

if [ "$POSTGRES_ISLOCAL" -eq 1 ]; then
    # Start the database
    trap 'pkill postgres' EXIT
    /usr/local/bin/docker-entrypoint.sh postgres &
    trap - EXIT
fi

if wait_for_postgres "$POSTGRES_HOST" "5432" "$POSTGRES_MAX_ATTEMPTS" "$POSTGRES_WAIT_INTERVAL"; then
    echo "Postgres is up"

    if check_files_ready_for_restore; then
        echo "WARNING: You are about to restore the database. This operation cannot be undone."
        echo "The restoration process will begin in 10 seconds. Press Ctrl+C to cancel."
        sleep 10
        echo "Initiating restoration process..."
        /usr/local/bin/restore.sh
    fi
else
    echo "Error: PostgreSQL is not ready."
    exit 1
fi

moveFilesAndDeleteDir /config/DB/Backup "$BACKUP_DIR"

safe_chown "${PUID:-0}:${PGID:-0}" "$BACKUP_DIR"
safe_chown "${PUID:-0}:${PGID:-0}" "$RESTORE_DIR"

if [ "$PUID" -ne 0 ]; then
    if usermod -aG postgres "$user_name"; then
        echo "User $user_name added to group postgres successfully."
        if ! chmod -R 775 "$PGDATA"; then
            echo "Failed to set permissions on $PGDATA"
            exit 1
        fi
    else
        echo "Failed to add user $user_name to group postgres."
    fi
fi

# Execute the main application as the specified user
if [ "$PUID" -ne 0 ] && [ "$PGID" -ne 0 ]; then
    echo "Running as $user_name:$group_name"
    exec gosu "$user_name:$group_name" "$@"
elif [ "$PUID" -ne 0 ]; then
    echo "Running as $user_name"
    exec gosu "$user_name" "$@"
elif [ "$PGID" -ne 0 ]; then
    echo "Running as :$group_name"
    exec gosu ":$group_name" "$@"
else
    echo "Running as root"
    exec "$@"
fi
