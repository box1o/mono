#!/usr/bin/env bash

set -e

BASE_PATH="src/features"

usage() {
  echo "Usage: $0 <feature-name> [base-path]"
  echo "  feature-name     Name of the feature (e.g., notes, invoice)"
  echo "  base-path        (Optional) Base path (default: src/features)"
}

if [ -z "$1" ]; then
  usage
  exit 1
fi

ELEMENT="$1"

if [ ! -z "$2" ]; then
  BASE_PATH="$2"
fi

FEATURE_PATH="$BASE_PATH/$ELEMENT"
SUBFOLDERS=(components hooks services store types constants utils)

mkdir -p "$FEATURE_PATH"
for SUB in "${SUBFOLDERS[@]}"; do
  mkdir -p "$FEATURE_PATH/$SUB"
done

# Create api folder inside hooks
mkdir -p "$FEATURE_PATH/hooks/api"

# Main index barrel
cat > "$FEATURE_PATH/index.ts" <<EOF
export * from "./components";
export * from "./constants";
export * from "./hooks";
export * from "./services";
export * from "./store";
export * from "./types";
export * from "./utils";
export { Component as ${ELEMENT^}Page } from "./${ELEMENT}.page";
export { default as ${ELEMENT^}Main } from "./main";
EOF

# Components barrel
cat > "$FEATURE_PATH/components/index.ts" <<EOF
EOF

# Hooks barrel
cat > "$FEATURE_PATH/hooks/index.ts" <<EOF
export { default as use${ELEMENT^} } from "./use-${ELEMENT}";
export * from "./api";
EOF

# Hooks API barrel
cat > "$FEATURE_PATH/hooks/api/index.ts" <<EOF
export { default as ${ELEMENT}Api } from "./${ELEMENT}.api";
EOF

# Services barrel
cat > "$FEATURE_PATH/services/index.ts" <<EOF
export { default as ${ELEMENT}Service } from "./${ELEMENT}.service";
EOF

# Store barrel
cat > "$FEATURE_PATH/store/index.ts" <<EOF
export { default as use${ELEMENT^}Store } from "./${ELEMENT}.store";
EOF

# Types barrel
cat > "$FEATURE_PATH/types/index.ts" <<EOF
export type { ${ELEMENT^} } from "./${ELEMENT}.types";
EOF

# Constants barrel
cat > "$FEATURE_PATH/constants/index.ts" <<EOF
export { ${ELEMENT^^}_CONSTANTS } from "./${ELEMENT}.constants";
EOF

# Utils barrel
cat > "$FEATURE_PATH/utils/index.ts" <<EOF
export { ${ELEMENT}Utils } from "./${ELEMENT}.utils";
EOF

# Create empty files with proper extensions
touch "$FEATURE_PATH/types/${ELEMENT}.types.ts"
touch "$FEATURE_PATH/constants/${ELEMENT}.constants.ts"
touch "$FEATURE_PATH/hooks/api/${ELEMENT}.api.ts"
touch "$FEATURE_PATH/services/${ELEMENT}.service.ts"
touch "$FEATURE_PATH/store/${ELEMENT}.store.ts"
touch "$FEATURE_PATH/hooks/use-${ELEMENT}.ts"
touch "$FEATURE_PATH/utils/${ELEMENT}.utils.ts"

# Main component
cat > "$FEATURE_PATH/main.tsx" <<EOF
const Main = () => (
  <div>
    <h1>${ELEMENT^} Feature Main</h1>
  </div>
);

export default Main;
EOF

# Feature page
cat > "$FEATURE_PATH/${ELEMENT}.page.tsx" <<EOF
import Main from "./main";

const ${ELEMENT^}Page = () => {
  return (
    <div>
      <Main />
    </div>
  );
};

export const Component = ${ELEMENT^}Page;
EOF

echo "✅ Feature '${ELEMENT}' created successfully at ${FEATURE_PATH}"
echo "📁 Created folders: ${SUBFOLDERS[*]}"
echo "📄 API folder created at hooks/api/"
echo "📄 Created all barrel exports and empty TypeScript files"
