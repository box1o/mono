#!/usr/bin/env bash
set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/shared.inc"

load_config scaffold

name="${1:-}"
base="${2:-${SCAFFOLD_BASE:-src/features}}"

[[ -n "$name" ]] || die "usage: $0 <feature-name> [base-path]"

feature="$base/$name"
cap="${name^}"
upper="${name^^}"

create_directories() {
	mkdir -p "$feature"/{components,hooks/api,services,store,types,constants,utils}
}

write_root_index() {
	cat >"$feature/index.ts" <<EOF_TS
export * from "./components";
export * from "./constants";
export * from "./hooks";
export * from "./services";
export * from "./store";
export * from "./types";
export * from "./utils";
export { Component as ${cap}Page } from "./${name}.page";
export { default as ${cap}Main } from "./main";
EOF_TS
}

write_barrels() {
	: >"$feature/components/index.ts"

	cat >"$feature/hooks/index.ts" <<EOF_TS
export { default as use${cap} } from "./use-${name}";
export * from "./api";
EOF_TS

	printf 'export { default as %sApi } from "./%s.api";\n' "$name" "$name" >"$feature/hooks/api/index.ts"
	printf 'export { default as %sService } from "./%s.service";\n' "$name" "$name" >"$feature/services/index.ts"
	printf 'export { default as use%sStore } from "./%s.store";\n' "$cap" "$name" >"$feature/store/index.ts"
	printf 'export type { %s } from "./%s.types";\n' "$cap" "$name" >"$feature/types/index.ts"
	printf 'export { %s_CONSTANTS } from "./%s.constants";\n' "$upper" "$name" >"$feature/constants/index.ts"
	printf 'export { %sUtils } from "./%s.utils";\n' "$name" "$name" >"$feature/utils/index.ts"
}

write_placeholders() {
	touch \
		"$feature/types/$name.types.ts" \
		"$feature/constants/$name.constants.ts" \
		"$feature/hooks/api/$name.api.ts" \
		"$feature/services/$name.service.ts" \
		"$feature/store/$name.store.ts" \
		"$feature/hooks/use-$name.ts" \
		"$feature/utils/$name.utils.ts"
}

write_components() {
	cat >"$feature/main.tsx" <<EOF_TSX
const Main = () => <div><h1>${cap} Feature Main</h1></div>;

export default Main;
EOF_TSX

	cat >"$feature/$name.page.tsx" <<EOF_TSX
import Main from "./main";

const ${cap}Page = () => <Main />;

export const Component = ${cap}Page;
EOF_TSX
}

create_directories
write_root_index
write_barrels
write_placeholders
write_components

ok "created: $feature"
