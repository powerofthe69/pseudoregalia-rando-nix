#!/usr/bin/env bash
set -e

OWNER="pseudoregalia-modding"
REPO="rando"
SOURCES_FILE="sources.json"
LOCAL_LOCK_FILE="Cargo.lock"
OODLE_URL="https://github.com/new-world-tools/go-oodle/releases/download/v0.2.3-files/liboo2corelinux64.so.9"

# Create temp directory
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

echo "Grab latest upstream source ($OWNER/$REPO)..."
LATEST_TAG=$(curl -s "https://api.github.com/repos/$OWNER/$REPO/releases/latest" | jq -r .tag_name)
echo "Found Release: ${LATEST_TAG}"

# Download source to temp dir
curl -sL "https://github.com/$OWNER/$REPO/archive/$LATEST_TAG.tar.gz" | tar xz -C "$WORK_DIR"
SRC_DIR=$(find "$WORK_DIR" -mindepth 1 -maxdepth 1 -type d | head -n 1)

echo "Create Cargo.lock fresh"
pushd "$SRC_DIR" > /dev/null
cargo generate-lockfile
popd > /dev/null

# Copy the generated lockfile to your local repo
echo "Updating local $LOCAL_LOCK_FILE"
cp "$SRC_DIR/Cargo.lock" "$LOCAL_LOCK_FILE"

echo "Hash latest pseudoregalia rando release"
RANDO_HASH=$(nix-prefetch-url --unpack "https://github.com/$OWNER/$REPO/archive/$LATEST_TAG.tar.gz" --type sha256)
RANDO_SRI=$(nix hash convert --hash-algo sha256 --to sri "$RANDO_HASH")

OODLE_HASH=$(nix-prefetch-url "$OODLE_URL" --type sha256)
OODLE_SRI=$(nix hash convert --hash-algo sha256 --to sri "$OODLE_HASH")

echo "Parse Cargo.lock for git dependencies..."

GIT_DEPS_JSON=$(python3 -c "
import toml, json, sys

try:
    data = toml.load('$LOCAL_LOCK_FILE')
    git_deps = {}

    for pkg in data.get('package', []):
        raw_source = pkg.get('source', '')

        if raw_source.startswith('git+'):
            if '#' not in raw_source:
                continue

            clean_source, commit_hash = raw_source.split('#', 1)
            url = clean_source[4:]

            if '?' in url: url = url.split('?')[0]
            if url.endswith('.git'): url = url[:-4]

            is_github = 'github.com' in url

            git_deps[pkg['name']] = {
                'name': pkg['name'],
                'version': pkg['version'],
                'url': url,
                'rev': commit_hash,
                'is_github': is_github
            }

    print(json.dumps(git_deps))

except Exception as e:
    sys.stderr.write(f'Error parsing TOML: {str(e)}\n')
    sys.exit(1)
")

HASHED_DEPS="{}"

for name in $(echo "$GIT_DEPS_JSON" | jq -r 'keys[]'); do
    _VER=$(echo "$GIT_DEPS_JSON" | jq -r ".[\"$name\"].version")
    _URL=$(echo "$GIT_DEPS_JSON" | jq -r ".[\"$name\"].url")
    _REV=$(echo "$GIT_DEPS_JSON" | jq -r ".[\"$name\"].rev")
    _IS_GH=$(echo "$GIT_DEPS_JSON" | jq -r ".[\"$name\"].is_github")

    echo "Found '$name' (v$_VER)"

    if [ "$_IS_GH" == "true" ]; then
        TARGET_URL="$_URL/archive/$_REV.tar.gz"
        _HASH=$(nix-prefetch-url --unpack "$TARGET_URL" --type sha256 2>/dev/null)
    else
        _HASH=$(nix-prefetch-url --unpack --type sha256 --url "$_URL" --rev "$_REV" 2>/dev/null)
    fi

    _SRI=$(nix hash convert --hash-algo sha256 --to sri "$_HASH")

    JSON_STRING=$(jq -n \
        --arg name "$name" \
        --arg ver "$_VER" \
        --arg hash "$_SRI" \
        '{repo: $name, version: $ver, hash: $hash}')

    HASHED_DEPS=$(echo "$HASHED_DEPS" | jq --arg name "$name" --argjson obj "$JSON_STRING" '. + {($name): $obj}')
done

echo "Write to $SOURCES_FILE..."

BASE_JSON=$(jq -n \
    --arg r_owner "$OWNER" \
    --arg r_repo "$REPO" \
    --arg r_tag "$LATEST_TAG" \
    --arg r_hash "$RANDO_SRI" \
    --arg o_url "$OODLE_URL" \
    --arg o_hash "$OODLE_SRI" \
    '{
        "rando": { "type": "github", "owner": $r_owner, "repo": $r_repo, "version": $r_tag, "hash": $r_hash },
        "oodleLib": { "type": "url", "url": $o_url, "hash": $o_hash }
    }')

echo "$BASE_JSON" | jq --argjson deps "$HASHED_DEPS" '. + $deps' > "$SOURCES_FILE"

echo "Successfully updated sources.json"
