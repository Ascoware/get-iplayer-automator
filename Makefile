# Populate Binaries/get_iplayer/ before building a release:
#
#   make binaries          — full build (slow, ~30 min first time)
#   make gip               — re-fetch get_iplayer only (fast)
#   make install-perl      — rebuild Perl + dylibs only
#   make install-utils     — rebuild AtomicParsley + ffmpeg only
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

# ── Heavy build (delegated to get_iplayer_macos) ───────────────────────────

perl-libs:
	$(MAKE) -C $(GIP_MACOS) ARCH=arm64 conan-all pg-all
	cd $(GIP_MACOS) && arch -x86_64 make conan-all pg-all
	$(MAKE) -C $(GIP_MACOS) dylib-universal perl-universal

utils:
	$(MAKE) -C $(GIP_MACOS) ARCH=universal ap-all ff-all

# ── Install Perl + dylibs + utils into Binaries/ ───────────────────────────

install-perl: perl-libs
	$(MAKE) -C $(GIP_MACOS) perl-install

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

# ── Top-level target ───────────────────────────────────────────────────────

binaries: install-perl install-utils gip
	@echo "Binaries/get_iplayer/ ready"

.PHONY: perl-libs utils install-perl install-utils gip binaries
