#!/bin/sh

set -eu

# Native assets are embedded by Flutter's xcode_backend.dart, but their dSYMs
# are not currently copied into the archive. Generate the companion dSYM for
# objective_c after the native asset has been embedded in the app.
case "${CONFIGURATION:-}" in
  Release|Profile)
    ;;
  *)
    exit 0
    ;;
esac

framework_binary="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}/objective_c.framework/objective_c"
if [ ! -f "$framework_binary" ]; then
  echo "warning: objective_c.framework was not embedded; skipping its dSYM."
  exit 0
fi

dsym_folder="${DWARF_DSYM_FOLDER_PATH}/objective_c.framework.dSYM"
dsym_binary="$dsym_folder/Contents/Resources/DWARF/objective_c"

# dsymutil uses the linker debug map in the binary to find the native-asset
# object files left by the Dart hook runner. Keep the generated dSYM alongside
# the other Xcode dSYMs so it is included in Runner.xcarchive/dSYMs.
mkdir -p "$DWARF_DSYM_FOLDER_PATH"
if [ -e "$dsym_folder" ]; then
  rm -rf "$dsym_folder"
fi
xcrun dsymutil "$framework_binary" -o "$dsym_folder"

if [ ! -f "$dsym_binary" ]; then
  echo "error: dsymutil did not create the objective_c DWARF file."
  exit 1
fi

binary_uuid="$(xcrun dwarfdump --uuid "$framework_binary" | awk '/UUID:/ { print $2; exit }')"
dsym_uuid="$(xcrun dwarfdump --uuid "$dsym_binary" | awk '/UUID:/ { print $2; exit }')"
if [ -z "$binary_uuid" ] || [ "$binary_uuid" != "$dsym_uuid" ]; then
  echo "error: objective_c dSYM UUID mismatch (binary: ${binary_uuid:-missing}, dSYM: ${dsym_uuid:-missing})."
  exit 1
fi

echo "Generated objective_c.framework.dSYM with UUID $dsym_uuid"
