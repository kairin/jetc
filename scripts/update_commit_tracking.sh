update_commit_tracking_footer() {
  local file="$1"
  local now
  now=$(date +"%Y%m%d-%H%M%S")
  # Only update the first COMMIT-TRACKING line found in the last 30 lines
  sed -i -E "{
    \$!b
    :a
    N
    \$!ba
    s/(COMMIT-TRACKING: UUID-)[0-9]{8}-[0-9]{6}(-[A-Z0-9]{4})/\1${now}\2/
  }" "$file"
}
