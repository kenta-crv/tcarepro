#!/bin/bash
set -e

# Remove a potentially pre-existing server.pid for Rails.
rm -f /myapp/tmp/pids/server.pid

# Setup database if it doesn't exist
if [ ! -f /myapp/db/development.sqlite3 ]; then
    echo "Setting up database..."
    bundle exec rails db:create db:migrate db:seed
fi

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"