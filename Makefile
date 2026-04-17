# Populate Binaries/ before building a release:
#
#   make / make all        — full build (slow, ~30 min first time)
#   make gip               — re-fetch/patch get_iplayer only (fast if already exported)
#   make install-perl      — copy Perl from get_iplayer_macos export
#   make install-utils     — copy utils from get_iplayer_macos export
#   make yt-dlp            — download yt-dlp standalone binary
#
# Prerequisites in sibling repos:
#   ../get_iplayer_macos   — build system (drives all binary/Perl builds)
#   ../get_iplayer         — get_iplayer source (managed by get_iplayer_macos)

GIP_MACOS   := ../get_iplayer_macos
GIP_EXPORT  := $(GIP_MACOS)/build-universal/export

ditto       := ditto --norsrc --noextattr --noacl

PERL_BIN    := Binaries/get_iplayer/perl/bin
PERL_LIB    := Binaries/get_iplayer/perl/lib
PERL_DYLIB  := Binaries/get_iplayer/perl/dylib
UTILS_BIN   := Binaries/get_iplayer/utils/bin

YT_DLP_URL  ?= https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos
YT_DLP_DIR  := Binaries/yt-dlp_macos
YT_DLP_BIN  := $(YT_DLP_DIR)/yt-dlp_macos

# ── Build get_iplayer_macos and export outputs ─────────────────────────────

build-gip-macos:
	$(MAKE) -C $(GIP_MACOS) ARCH=arm64 conan-all pg-all
	cd $(GIP_MACOS) && arch -x86_64 make conan-all pg-all
	$(MAKE) -C $(GIP_MACOS) dylib-universal perl-universal
	$(MAKE) -C $(GIP_MACOS) ARCH=universal ap-all ff-all
	$(MAKE) -C $(GIP_MACOS) export

# ── Install Perl + dylibs into Binaries/ ───────────────────────────────────

install-perl: build-gip-macos
	@mkdir -p $(PERL_BIN) $(PERL_LIB) $(PERL_DYLIB)
	@$(ditto) $(GIP_EXPORT)/perl/bin/perl $(PERL_BIN)/perl
	@$(ditto) $(GIP_EXPORT)/perl/lib/     $(PERL_LIB)/
	@rm -f $(PERL_DYLIB)/*.dylib
	@$(ditto) $(GIP_EXPORT)/perl/dylib/   $(PERL_DYLIB)/
	@echo "installed perl to Binaries/get_iplayer/perl"

# ── Install utils into Binaries/ ──────────────────────────────────────────

install-utils: build-gip-macos
	@mkdir -p $(UTILS_BIN)
	@$(ditto) $(GIP_EXPORT)/utils/AtomicParsley $(UTILS_BIN)/AtomicParsley
	@$(ditto) $(GIP_EXPORT)/utils/ffmpeg        $(UTILS_BIN)/ffmpeg
	@echo "installed utils to $(UTILS_BIN)"

# ── Fetch, patch, and install get_iplayer scripts ──────────────────────────
# get_iplayer is exported raw (unpatched) by get_iplayer_macos; we apply our
# own patch here.

$(PERL_BIN)/get_iplayer: get_iplayer_custom.patch
	$(MAKE) -C $(GIP_MACOS) export-gip
	@mkdir -p $(PERL_BIN)
	@cp $(GIP_EXPORT)/get_iplayer     $(PERL_BIN)/get_iplayer
	@cp $(GIP_EXPORT)/get_iplayer.cgi $(PERL_BIN)/get_iplayer.cgi
	@patch -p0 -d $(PERL_BIN) < get_iplayer_custom.patch
	@chmod +x $(PERL_BIN)/get_iplayer $(PERL_BIN)/get_iplayer.cgi
	@echo "installed get_iplayer scripts"

gip: $(PERL_BIN)/get_iplayer

# ── Download yt-dlp standalone binary ─────────────────────────────────────

$(YT_DLP_BIN):
	@mkdir -p $(YT_DLP_DIR)
	@rm -f $(YT_DLP_BIN)
	@curl -L -o $(YT_DLP_BIN) $(YT_DLP_URL)
	@chmod +x $(YT_DLP_BIN)
	@echo "downloaded yt-dlp"

yt-dlp: $(YT_DLP_BIN)

# ── Top-level targets ──────────────────────────────────────────────────────

binaries: install-perl install-utils gip yt-dlp
	@echo "Binaries/ ready"

all: binaries

.PHONY: build-gip-macos install-perl install-utils gip yt-dlp binaries all
