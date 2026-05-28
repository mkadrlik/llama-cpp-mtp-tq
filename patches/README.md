# Patches for hybrid llama.cpp build
#
# Place `.patch` files here generated from `git format-patch` or
# manually crafted diff files.
#
# Convention:
#   001-tbq3-amesianx.patch   — TurboQuant tbq3 KV cache patches
#   002-mtp-mainline.patch     — MTP speculative decoding (if needed)
#   003-fix-compat.patch       — Build compatibility fixes
#
# Patches are auto-applied in alphabetical order during Docker build.
# Generate from comparison against mainline:
#
#   cd /tmp/mainline-llama.cpp
#   # apply AmesianX tbq3 changes, then
#   git diff > /tmp/mtp-tq-template/patches/001-tbq3-amesianx.patch