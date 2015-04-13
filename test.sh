#!/bin/sh

set -e -u

S="$(cd $(dirname $0) && pwd)"

TMP_DIR="$S/tmp"
MOCK_DIST_DIR="$S/tmp/mock-dist"

# Clean out the tmp dir
if [ -n "${NO_REBUILD_MOCKS-}" ]; then
    mv "$MOCK_DIST_DIR" ./mock-backup
fi
rm -Rf "$TMP_DIR"
mkdir "$TMP_DIR"
if [ -n "${NO_REBUILD_MOCKS-}" ]; then
    mv ./mock-backup "$MOCK_DIST_DIR"
fi

TEST_DIR="$S/test"
TEST_SECRET_KEY="$TEST_DIR/secret-key.gpg"
TEST_PUBLIC_KEY="$TEST_DIR/public-key.gpg"
RUSTUP_GPG_KEY="$TEST_DIR/public-key.asc"
WORK_DIR="$S/tmp/work"
MOCK_BUILD_DIR="$S/tmp/mock-build"
TEST_PREFIX="$S/tmp/prefix"
RUSTUP_HOME="$(cd "$TMP_DIR" && pwd)/rustup"

say() {
    echo "test: $1"
}

pre() {
    echo "test: $1"
    rm -Rf "$RUSTUP_HOME"
    rm -Rf "$WORK_DIR"
    mkdir -p "$WORK_DIR"
}

need_ok() {
    if [ $? -ne 0 ]
    then
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    fi
}

fail() {
    echo
    echo "$1"
    echo
    echo "TEST FAILED!"
    echo
    exit 1
}

try() {
    set +e
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
	echo \$ "$_cmd"
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    else
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
	    echo \$ "$_cmd"
	fi
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
	    /bin/echo "$_output"
	fi
    fi
    set -e
}

expect_fail() {
    set +e
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -eq 0 ]; then
	echo \$ "$_cmd"
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    else
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
	    echo \$ "$_cmd"
	fi
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
	    /bin/echo "$_output"
	fi
    fi
    set -e
}

expect_output_ok() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
	echo \$ "$_cmd"
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    elif ! echo "$_output" | grep -q "$_expected"; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
	echo
	echo "missing expected output '$_expected'"
	echo
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    else
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
	    echo \$ "$_cmd"
	fi
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
	    /bin/echo "$_output"
	fi
    fi
    set -e
}

expect_output_fail() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -eq 0 ]; then
	echo \$ "$_cmd"
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    elif ! echo "$_output" | grep -q "$_expected"; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
	echo
	echo "missing expected output '$_expected'"
	echo
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    else
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
	    echo \$ "$_cmd"
	fi
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
	    /bin/echo "$_output"
	fi
    fi
    set -e
}

expect_not_output_ok() {
    set +e
    local _expected="$1"
    shift 1
    _cmd="$@"
    _output=`$@ 2>&1`
    if [ $? -ne 0 ]; then
	echo \$ "$_cmd"
	# Using /bin/echo to avoid escaping
	/bin/echo "$_output"
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    elif echo "$_output" | grep -q "$_expected"; then
	echo \$ "$_cmd"
	/bin/echo "$_output"
	echo
	echo "unexpected output '$_expected'"
	echo
	echo
	echo "TEST FAILED!"
	echo
	exit 1
    else
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_CMD-}" ]; then
	    echo \$ "$_cmd"
	fi
	if [ -n "${VERBOSE-}" -o -n "${VERBOSE_OUTPUT-}" ]; then
	    /bin/echo "$_output"
	fi
    fi
    set -e
}

runtest() {
    local _testname="$1"
    if [ -n "${TESTNAME-}" ]; then
        if ! echo "$_testname" | grep -q "$TESTNAME"; then
            return 0
        fi
    fi

    pre "$_testname"
    "$_testname"
}

get_architecture() {

    local _ostype="$(uname -s)"
    local _cputype="$(uname -m)"

    if [ "$_ostype" = Darwin -a "$_cputype" = i386 ]; then
	# Darwin `uname -s` lies
	if sysctl hw.optional.x86_64 | grep -q ': 1'; then
	    local _cputype=x86_64
	fi
    fi

    case "$_ostype" in

	Linux)
	    local _ostype=unknown-linux-gnu
	    ;;

	FreeBSD)
	    local _ostype=unknown-freebsd
	    ;;

	DragonFly)
	    local _ostype=unknown-dragonfly
	    ;;

	Darwin)
	    local _ostype=apple-darwin
	    ;;

	MINGW* | MSYS*)
	    err "unimplemented windows arch detection"
	    ;;

	*)
	    err "unrecognized OS type: $_ostype"
	    ;;

    esac

    case "$_cputype" in

	i386 | i486 | i686 | i786 | x86)
            local _cputype=i686
            ;;

	xscale | arm)
	    local _cputype=arm
            ;;

	armv7l)
            local _cputype=arm
            local _ostype="${_ostype}eabihf"
            ;;

	x86_64 | x86-64 | x64 | amd64)
            local _cputype=x86_64
            ;;

	*)
            err "unknown CPU type: $CFG_CPUTYPE"

    esac

    # Detect 64-bit linux with 32-bit userland
    if [ $_ostype = unknown-linux-gnu -a $_cputype = x86_64 ]; then
	file -L "$SHELL" | grep -q "x86[_-]64"
	if [ $? != 0 ]; then
	    local _cputype=i686
	fi
    fi

    local _arch="$_cputype-$_ostype" 

    RETVAL="$_arch"
}

build_mock_bin() {
    local _name="$1"
    local _version="$2"
    local _version_hash="$3"
    local _dir="$4"

    cat "$TEST_DIR/mock.sh" | \
	sed s/@@TEMPLATE_BIN_NAME@@/"$_name"/ | \
	sed s/@@TEMPLATE_VERSION@@/"$_version"/ | \
	sed s/@@TEMPLATE_HASH@@/"$_version_hash"/ > "$_dir/$_name"

    chmod a+x "$_dir/$_name"
}

build_mock_rustc_installer() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"

    local _image="$MOCK_BUILD_DIR/image/rustc"
    mkdir -p "$_image/bin"
    build_mock_bin rustc "$_version" "$_version_hash" "$_image/bin"
    build_mock_bin rustdoc "$_version" "$_version_hash" "$_image/bin"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/rust-installer/gen-installer.sh" \
	--product-name=Rust \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="rustc-$_package-$_arch" \
	--component-name=rustc
}

build_mock_cargo_installer() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"

    local _image="$MOCK_BUILD_DIR/image/cargo"
    mkdir -p "$_image/bin"
    build_mock_bin cargo "$_version" "$_version_hash" "$_image/bin"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/rust-installer/gen-installer.sh" \
	--product-name=Cargo \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="cargo-$_package-$_arch" \
	--component-name=cargo
}

build_mock_rust_docs_installer() {
    local _package="$1"

    local _image="$MOCK_BUILD_DIR/image/docs"
    mkdir -p "$_image/share/doc/rust/html"
    echo "test" > "$_image/share/doc/rust/html/index.html"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/rust-installer/gen-installer.sh" \
	--product-name=Rust-documentation \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="rust-docs-$_package-$_arch" \
	--component-name=rust-docs
}

build_mock_combined_installer() {
    local _package="$1"

    get_architecture
    local _arch="$RETVAL"

    local _rustc_tarball="$MOCK_BUILD_DIR/pkg/rustc-$_package-$_arch.tar.gz"
    local _cargo_tarball="$MOCK_BUILD_DIR/pkg/cargo-$_package-$_arch.tar.gz"
    local _docs_tarball="$MOCK_BUILD_DIR/pkg/rust-docs-$_package-$_arch.tar.gz"
    local _inputs="$_rustc_tarball,$_cargo_tarball,$_docs_tarball"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/rust-installer/combine-installers.sh" \
	--product-name=Rust \
	--rel-manifest-dir=rustlib \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/dist" \
	--package-name="rust-$_package-$_arch" \
	--input-tarballs="$_inputs"
}

build_mock_dist_channel() {
    local _channel="$1"
    local _date="$2"

    (cd "$MOCK_BUILD_DIR/dist" && ls * > channel-rust-"$_channel")
    if command -v gpg > /dev/null 2>&1; then
	(cd "$MOCK_BUILD_DIR/dist" && for i in *; do
		gpg --no-default-keyring --secret-keyring "$TEST_SECRET_KEY" \
		    --keyring "$TEST_PUBLIC_KEY" \
		    --no-tty --yes -a --detach-sign "$i"
		done)
    else
	say "gpg not found. not testing signature verification"
	(cd "$MOCK_BUILD_DIR/dist" && for i in *; do echo "nosig" > "$i.asc"; done)
    fi
    (cd "$MOCK_BUILD_DIR/dist" && for i in *; do shasum -a256 $i > $i.sha256; done)
}

build_mock_channel() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"
    local _channel="$4"
    local _date="$5"

    rm -Rf "$MOCK_BUILD_DIR"
    mkdir -p "$MOCK_BUILD_DIR"

    say "building mock channel $_version $_version_hash $_package $_channel $_date"
    build_mock_rustc_installer "$_version" "$_version_hash" "$_package"
    build_mock_cargo_installer "$_version" "$_version_hash" "$_package"
    build_mock_rust_docs_installer "$_package"
    build_mock_combined_installer "$_package"
    build_mock_dist_channel "$_channel" "$_date"

    mkdir -p "$MOCK_DIST_DIR/dist/$_date"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/"
    # Copy the intermediate installers too, though without manifests, checksums, etc.
    cp "$MOCK_BUILD_DIR/pkg"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/pkg"/* "$MOCK_DIST_DIR/dist/"
}

build_mocks() {
    if [ -z "${NO_REBUILD_MOCKS-}" ]; then
	build_mock_channel 1.0.0-nightly hash-nightly-1 nightly nightly 2015-01-01
	build_mock_channel 1.0.0-beta hash-beta-1 1.0.0-beta beta 2015-01-01
	build_mock_channel 1.0.0 hash-stable-1 1.0.0 stable 2015-01-01

	build_mock_channel 1.1.0-nightly hash-nightly-2 nightly nightly 2015-01-02
	build_mock_channel 1.1.0-beta hash-beta-2 1.1.0-beta beta 2015-01-02
	build_mock_channel 1.1.0 hash-stable-2 1.1.0 stable 2015-01-02
    fi
}

set_current_dist_date() {
    local _dist_date="$1"
    cp "$MOCK_DIST_DIR/dist/$_dist_date"/* "$MOCK_DIST_DIR/dist/"
}


build_mock_bin() {
    local _name="$1"
    local _version="$2"
    local _version_hash="$3"
    local _dir="$4"

    cat "$TEST_DIR/mock.sh" | \
	sed s/@@TEMPLATE_BIN_NAME@@/"$_name"/ | \
	sed s/@@TEMPLATE_VERSION@@/"$_version"/ | \
	sed s/@@TEMPLATE_HASH@@/"$_version_hash"/ > "$_dir/$_name"

    chmod a+x "$_dir/$_name"
}

build_mock_rustc_installer() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"

    local _image="$MOCK_BUILD_DIR/image/rustc"
    mkdir -p "$_image/bin"
    build_mock_bin rustc "$_version" "$_version_hash" "$_image/bin"
    build_mock_bin rustdoc "$_version" "$_version_hash" "$_image/bin"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/rust-installer/gen-installer.sh" \
	--product-name=Rust \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="rustc-$_package-$_arch" \
	--component-name=rustc
}

build_mock_cargo_installer() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"

    local _image="$MOCK_BUILD_DIR/image/cargo"
    mkdir -p "$_image/bin"
    build_mock_bin cargo "$_version" "$_version_hash" "$_image/bin"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/rust-installer/gen-installer.sh" \
	--product-name=Cargo \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="cargo-$_package-$_arch" \
	--component-name=cargo
}

build_mock_rust_docs_installer() {
    local _package="$1"

    local _image="$MOCK_BUILD_DIR/image/docs"
    mkdir -p "$_image/share/doc/rust/html"
    echo "test" > "$_image/share/doc/rust/html/index.html"

    get_architecture
    local _arch="$RETVAL"

    mkdir -p "$MOCK_BUILD_DIR/pkg"
    try sh "$S/rust-installer/gen-installer.sh" \
	--product-name=Rust-documentation \
	--rel-manifest-dir=rustlib \
	--image-dir="$_image" \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/pkg" \
        --package-name="rust-docs-$_package-$_arch" \
	--component-name=rust-docs
}

build_mock_combined_installer() {
    local _package="$1"

    get_architecture
    local _arch="$RETVAL"

    local _rustc_tarball="$MOCK_BUILD_DIR/pkg/rustc-$_package-$_arch.tar.gz"
    local _cargo_tarball="$MOCK_BUILD_DIR/pkg/cargo-$_package-$_arch.tar.gz"
    local _docs_tarball="$MOCK_BUILD_DIR/pkg/rust-docs-$_package-$_arch.tar.gz"
    local _inputs="$_rustc_tarball,$_cargo_tarball,$_docs_tarball"

    mkdir -p "$MOCK_BUILD_DIR/dist"
    try sh "$S/rust-installer/combine-installers.sh" \
	--product-name=Rust \
	--rel-manifest-dir=rustlib \
	--work-dir="$MOCK_BUILD_DIR/work" \
	--output-dir="$MOCK_BUILD_DIR/dist" \
	--package-name="rust-$_package-$_arch" \
	--input-tarballs="$_inputs"
}

build_mock_dist_channel() {
    local _channel="$1"
    local _date="$2"

    (cd "$MOCK_BUILD_DIR/dist" && ls * > channel-rust-"$_channel")
    if command -v gpg > /dev/null 2>&1; then
	(cd "$MOCK_BUILD_DIR/dist" && for i in *; do
		gpg --no-default-keyring --secret-keyring "$TEST_SECRET_KEY" \
		    --keyring "$TEST_PUBLIC_KEY" \
		    --no-tty --yes -a --detach-sign "$i"
		done)
    else
	say "gpg not found. not testing signature verification"
	(cd "$MOCK_BUILD_DIR/dist" && for i in *; do echo "nosig" > "$i.asc"; done)
    fi
    (cd "$MOCK_BUILD_DIR/dist" && for i in *; do shasum -a256 $i > $i.sha256; done)
}

build_mock_channel() {
    local _version="$1"
    local _version_hash="$2"
    local _package="$3"
    local _channel="$4"
    local _date="$5"

    rm -Rf "$MOCK_BUILD_DIR"
    mkdir -p "$MOCK_BUILD_DIR"

    say "building mock channel $_version $_version_hash $_package $_channel $_date"
    build_mock_rustc_installer "$_version" "$_version_hash" "$_package"
    build_mock_cargo_installer "$_version" "$_version_hash" "$_package"
    build_mock_rust_docs_installer "$_package"
    build_mock_combined_installer "$_package"
    build_mock_dist_channel "$_channel" "$_date"

    mkdir -p "$MOCK_DIST_DIR/dist/$_date"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/dist"/* "$MOCK_DIST_DIR/dist/"
    # Copy the intermediate installers too, though without manifests, checksums, etc.
    cp "$MOCK_BUILD_DIR/pkg"/* "$MOCK_DIST_DIR/dist/$_date/"
    cp "$MOCK_BUILD_DIR/pkg"/* "$MOCK_DIST_DIR/dist/"
}

build_mocks() {
    if [ -z "${NO_REBUILD_MOCKS-}" ]; then
	build_mock_channel 1.0.0-nightly hash-nightly-1 nightly nightly 2015-01-01
	build_mock_channel 1.0.0-beta hash-beta-1 1.0.0-beta beta 2015-01-01
	build_mock_channel 1.0.0 hash-stable-1 1.0.0 stable 2015-01-01

	build_mock_channel 1.1.0-nightly hash-nightly-2 nightly nightly 2015-01-02
	build_mock_channel 1.1.0-beta hash-beta-2 1.1.0-beta beta 2015-01-02
	build_mock_channel 1.1.0 hash-stable-2 1.1.0 stable 2015-01-02
    fi
}

set_current_dist_date() {
    local _dist_date="$1"
    cp "$MOCK_DIST_DIR/dist/$_dist_date"/* "$MOCK_DIST_DIR/dist/"
}

# Build the mock revisions
build_mocks

# Tell rustup where to store temporary stuff
export RUSTUP_HOME
# Tell rustup what key to use to verify sigs
export RUSTUP_GPG_KEY

# Tell rustup where to download stuff from
RUSTUP_DIST_SERVER="file://$(cd "$MOCK_DIST_DIR" && pwd)"
export RUSTUP_DIST_SERVER

# Set up the PATH to find rustup.sh
PATH="$S:$PATH"
export PATH
try test -e "$S/rustup.sh"

basic_install() {
    try rustup.sh --prefix="$TEST_PREFIX"
    try test -e "$TEST_PREFIX/bin/rustc"
}
runtest basic_install

basic_uninstall() {
    try rustup.sh --prefix="$TEST_PREFIX"
    try test -e "$TEST_PREFIX/bin/rustc"
    try rustup.sh --prefix="$TEST_PREFIX" --uninstall
    try test ! -e "$TEST_PREFIX/bin/rustc"
}
runtest basic_uninstall

uninstall_not_installed() {
    expect_output_ok "no toolchain installed" rustup.sh --prefix="$TEST_PREFIX" --uninstall
}
runtest uninstall_not_installed

with_date() {
    try rustup.sh --prefix="$TEST_PREFIX" --date=2015-01-01
    expect_output_ok "hash-beta-1" "$TEST_PREFIX/bin/rustc" --version
}
runtest with_date

with_channel() {
    try rustup.sh --prefix="$TEST_PREFIX" --channel=nightly
    expect_output_ok "hash-nightly-2" "$TEST_PREFIX/bin/rustc" --version
}
runtest with_channel

with_channel_and_date() {
    try rustup.sh --prefix="$TEST_PREFIX" --date=2015-01-01 --channel=nightly
    expect_output_ok "hash-nightly-1" "$TEST_PREFIX/bin/rustc" --version
}
runtest with_channel_and_date

save_without_date() {
    try rustup.sh --prefix="$TEST_PREFIX" --save
    try test -e "$TEST_PREFIX/bin/rustc"
    try rustup.sh --prefix="$TEST_PREFIX" --save
    try test -e "$TEST_PREFIX/bin/rustc"
}
runtest save_without_date

save_with_date() {
    try rustup.sh --prefix="$TEST_PREFIX" --save --date=2015-01-01
    try test -e "$TEST_PREFIX/bin/rustc"
    try rustup.sh --prefix="$TEST_PREFIX" --save --date=2015-01-01
    try test -e "$TEST_PREFIX/bin/rustc"
}
runtest save_with_date

out_of_date_metadata() {
    try rustup.sh --prefix="$TEST_PREFIX" --save
    echo "bogus" > "$RUSTUP_HOME/rustup-version"
    expect_output_ok "metadata is out of date" rustup.sh --prefix="$TEST_PREFIX" --save
}
runtest out_of_date_metadata

remove_metadata_if_not_save() {
    try rustup.sh --prefix="$TEST_PREFIX"
    try test ! -e "$RUSTUP_HOME/rustup-version"
}
runtest remove_metadata_if_not_save

leave_metadata_if_save() {
    try rustup.sh --prefix="$TEST_PREFIX" --save
    try test -e "$RUSTUP_HOME/rustup-version"
}
runtest leave_metadata_if_save

obey_RUST_PREFIX() {
    export RUSTUP_PREFIX="$TEST_PREFIX"
    try rustup.sh
    try test -e "$TEST_PREFIX/bin/rustc"
    unset RUSTUP_PREFIX
}
runtest obey_RUST_PREFIX

install_to_prefix_that_does_not_exist() {
    try rustup.sh --prefix="$TEST_PREFIX/a/b"
    try test -e "$TEST_PREFIX/a/b/bin/rustc"
}
runtest install_to_prefix_that_does_not_exist

# Existing directories that do not contain the rustup-version file
# indicate user error.
suspicious_RUSTUP_HOME() {
    local _old_rustup_home="$RUSTUP_HOME"
    export RUSTUP_HOME="$TMP_DIR"
    expect_output_fail "rustup home dir exists" rustup.sh
    export RUSTUP_HOME="$_old_rustup_home"
}
runtest suspicious_RUSTUP_HOME

shasum_fallback() {
    export __RUSTUP_MOCK_SHA256SUM=bogus
    try rustup.sh --prefix="$TEST_PREFIX"
    try test -e "$TEST_PREFIX/bin/rustc"
    expect_output_ok "falling back to shasum" rustup.sh --prefix="$TEST_PREFIX" --verbose
    unset __RUSTUP_MOCK_SHA256SUM
}
runtest shasum_fallback

validate_channel() {
    expect_output_fail "channel must be either 'stable', 'beta', or 'nightly'" rustup.sh --channel=pah
}
runtest validate_channel

validate_date() {
    expect_output_fail "date must be in YYYY-MM-DD format" rustup.sh --date=foo
}
runtest validate_date

explicit_version() {
    try rustup.sh --prefix="$TEST_PREFIX" --revision=1.0.0
    try test -e "$TEST_PREFIX/bin/rustc"
}
runtest explicit_version

explicit_version_with_channel() {
    expect_output_fail "the --revision flag may not be combined with --channel" rustup.sh --prefix="$TEST_PREFIX" --revision=1.0.0 --channel=nightly
}
runtest explicit_version_with_channel

explicit_version_with_date() {
    expect_output_fail "the --revision flag may not be combined with --date" rustup.sh --prefix="$TEST_PREFIX" --revision=1.0.0 --date=2015-01-01
}
runtest explicit_version_with_date

save_and_no_save() {
    # Run with --save to create the rustup directory, and save the downloaded installer
    try rustup.sh --prefix="$TEST_PREFIX" --revision=1.0.0 --save
    local _cache_dir="$(ls "$RUSTUP_HOME/dl")"
    try test -n "$_cache_dir"
    try test -e "$RUSTUP_HOME/dl/$_cache_dir/*.tar.gz"
    # This time it will delete the downloaded files
    try rustup.sh --prefix="$TEST_PREFIX" --revision=1.0.0
    local _dirlisting="$(ls "$RUSTUP_HOME/dl")"
    try test -z "$_dirlisting"
}
runtest save_and_no_save

install_from_spec() {
    try rustup.sh --prefix="$TEST_PREFIX" --spec=nightly
    expect_output_ok "hash-nightly-2" "$TEST_PREFIX/bin/rustc" --version
    try rustup.sh --prefix="$TEST_PREFIX" --spec=nightly-2015-01-01
    expect_output_ok "hash-nightly-1" "$TEST_PREFIX/bin/rustc" --version
    try rustup.sh --prefix="$TEST_PREFIX" --spec=1.0.0
    expect_output_ok "hash-stable-1" "$TEST_PREFIX/bin/rustc" --version
}
runtest install_from_spec

update_hash_file() {
    try rustup.sh --prefix="$TEST_PREFIX" --spec=nightly --update-hash-file="$TMP_DIR/update-hash"
    expect_output_ok "'nightly' is already up to date" rustup.sh --prefix="$TEST_PREFIX" --spec=nightly --update-hash-file="$TMP_DIR/update-hash"
}
runtest update_hash_file

update_hash_file2() {
    set_current_dist_date 2015-01-01
    try rustup.sh --prefix="$TEST_PREFIX" --spec=nightly --update-hash-file="$TMP_DIR/update-hash"
    # Since the date changed, there's an update, and we should *not* see the short-circuit
    set_current_dist_date 2015-01-02
    expect_not_output_ok "'nightly' is already up to date" rustup.sh --prefix="$TEST_PREFIX" --spec=nightly --update-hash-file="$TMP_DIR/update-hash"
}
runtest update_hash_file2

echo
echo "SUCCESS"
echo
