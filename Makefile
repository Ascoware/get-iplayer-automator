# Populate Binaries/ before building a release:
#
#   make binaries          — full build (slow, ~30 min first time)
#   make gip               — re-fetch get_iplayer only (fast)
#   make install-perl      — rebuild Perl + dylibs only
#   make install-utils     — rebuild AtomicParsley + ffmpeg only
#   make yt-dlp            — download yt-dlp standalone binary
#
# Prerequisites in sibling repos:
#   ../get_iplayer_macos   — build system
#   ../get_iplayer         — get_iplayer source (at GIP_TAG)

# Sibling repos (relative to this repo)
GIP_MACOS   := ../get_iplayer_macos
GIP_REPO    := ../get_iplayer
GIP_TAG     ?= master
GIP_SCRIPTS := get_iplayer get_iplayer.cgi
PERL_BIN    := Binaries/get_iplayer/perl/bin

YT_DLP_URL  ?= https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
YT_DLP_BIN  := Binaries/yt-dlp_macos

# ── Heavy build (delegated to get_iplayer_macos) ───────────────────────────

perl-libs:
	$(MAKE) -C $(GIP_MACOS) ARCH=arm64 conan-all pg-all
	cd $(GIP_MACOS) && arch -x86_64 make conan-all pg-all
	$(MAKE) -C $(GIP_MACOS) dylib-universal perl-universal

utils:
	$(MAKE) -C $(GIP_MACOS) ARCH=universal ap-all ff-all

# ── Install Perl + dylibs + utils into Binaries/ ───────────────────────────

BUNDLE_RPATH      := @executable_path/../dylib
PERL_LIB          := Binaries/get_iplayer/perl/lib

install-perl: perl-libs
	$(MAKE) -C $(GIP_MACOS) perl-install
	@$(MAKE) rpath-fixup

# Ensure .bundle rpath is @executable_path/../dylib on both arch slices.
#
# relocatable-perl sets this correctly for the x86_64 build.  The arm64 slice
# (built natively) sometimes ends up with a stale absolute Conan build path
# instead.  arm64 and x86_64 can diverge, so we thin each bundle, normalise
# the rpath per-arch, then relipo.  @executable_path is the perl binary at
# Contents/Resources/get_iplayer/perl/bin/, so ../dylib resolves correctly.
rpath-fixup:
	@echo "Fixing bundle rpaths for macOS app context..."
	@find $(PERL_LIB) -name "*.bundle" | while IFS= read -r b; do \
	  if ! otool -L "$$b" | grep -q "@rpath"; then continue; fi; \
	  arm64_tmp=$$(mktemp) && x86_tmp=$$(mktemp); \
	  lipo -thin arm64  -output "$$arm64_tmp" "$$b" && \
	  lipo -thin x86_64 -output "$$x86_tmp"  "$$b" || { rm -f "$$arm64_tmp" "$$x86_tmp"; continue; }; \
	  chmod +w "$$arm64_tmp" "$$x86_tmp"; \
	  for slice in "$$arm64_tmp" "$$x86_tmp"; do \
	    otool -l "$$slice" | awk '/LC_RPATH/{f=1} f && /^ +path /{print $$2; f=0}' | \
	      while IFS= read -r rp; do \
	        install_name_tool -delete_rpath "$$rp" "$$slice" 2>/dev/null || true; \
	      done; \
	    install_name_tool -add_rpath "$(BUNDLE_RPATH)" "$$slice" 2>/dev/null || true; \
	  done; \
	  chmod +w "$$b"; \
	  lipo -create "$$arm64_tmp" "$$x86_tmp" -output "$$b"; \
	  chmod -w "$$b"; \
	  rm -f "$$arm64_tmp" "$$x86_tmp"; \
	  echo "  fixed $$(basename $$b)"; \
	done
	@echo "rpath fixup done"

install-utils: utils
	$(MAKE) -C $(GIP_MACOS) utils-install

# ── Fetch, patch, and install get_iplayer scripts ──────────────────────────

$(PERL_BIN)/get_iplayer: get_iplayer_custom.patch
	@mkdir -p $(PERL_BIN)
	@git --git-dir=$(GIP_REPO)/.git archive $(GIP_TAG) $(GIP_SCRIPTS) \
	  | tar -x -C $(PERL_BIN)
	@patch -p0 -d $(PERL_BIN) < get_iplayer_custom.patch
	@chmod +x $(PERL_BIN)/get_iplayer $(PERL_BIN)/get_iplayer.cgi
	@echo "installed get_iplayer scripts"

gip: $(PERL_BIN)/get_iplayer

# ── Download yt-dlp standalone binary ─────────────────────────────────────

$(YT_DLP_BIN):
	@rm -rf $(YT_DLP_BIN)
	@curl -L -o $(YT_DLP_BIN) $(YT_DLP_URL)
	@chmod +x $(YT_DLP_BIN)
	@echo "downloaded yt-dlp"

yt-dlp: $(YT_DLP_BIN)

# ── Top-level target ───────────────────────────────────────────────────────

binaries: install-perl install-utils gip yt-dlp
	@echo "Binaries/ ready"

.PHONY: perl-libs utils install-perl rpath-fixup install-utils gip yt-dlp binaries
