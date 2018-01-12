#!/usr/bin/env bash
set -o errexit -o nounset
nix="@nix@"
case "${1:-}" in
    --print-packaged-nix-path)
        echo "$nix"
        exit 0
        ;;
    *)
        ;;
esac

oops() {
    echo "$0:" "$@" >&2
    exit 1
}

if ! reginfo="$(mktemp -t nix-binary-tarball-reginfo.XXXXXXXXXX)"; then
    oops "Can't create temporary file for storing Nix bootstrap information"
fi

cleanup() {
    rm "$reginfo"
}
trap cleanup EXIT INT QUIT TERM

require_util() {
    type "$1" > /dev/null 2>&1 || which "$1" > /dev/null 2>&1 ||
        oops "you do not have '$1' installed, which I need to $2"
}
require_util sed "parse out the binary tarball"
require_util bzcat "decompress the binary tarball"
require_util tar "unpack the binary tarball"

cat_tarball() {
    sed '0,/^__begin_archive__$/d' "$0"
}

echo "ensuring @storedir@ exists and is writable by us" >&2
mkdir -p --mode=00755 @storedir@
if ! test -w @storedir@; then
    oops "@storedir@ is not writable by us"
fi

echo "extracting tarball..." >&2
if ! cat_tarball | \
        bzcat | \
        tar \
            --unlink-first \
            --recursive-unlink \
            --verbose \
            --extract \
            --absolute-names \
            --transform "s,reginfo,$reginfo," \
            >&2;
then
    oops "failed to extract tarball"
fi

echo "initialising Nix database..." >&2
if ! "$nix/bin/nix-store" --init; then
    oops "failed to initialize the Nix database"
fi

if ! "$nix/bin/nix-store" --load-db < "$reginfo"; then
    oops "unable to register valid paths"
fi
# print out the resulting Nix path for extra usability
echo "$nix"
exit 0
__begin_archive__
