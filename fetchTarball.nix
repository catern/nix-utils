if (0 <= builtins.compareVersions builtins.nixVersion "1.12")
then builtins.fetchTarball
else
{ url
, sha256
}:
let
  builtin-paths = import <nix/config.nix>;
in
builtins.derivation {
  name = "source";

  builder   = builtins.storePath builtin-paths.shell;
  coreutils = builtins.storePath builtin-paths.coreutils;
  gzip      = builtins.storePath builtin-paths.gzip;
  tar       = builtins.storePath builtin-paths.tar;

  system = builtins.currentSystem;

  tarball = import <nix/fetchurl.nix> {
    inherit url sha256;
  };

  args = [(builtins.toFile "unpacker"
  ''
    "$coreutils/mkdir" "$out"
    cd "$out"
    "$gzip" --decompress < "$tarball" | "$tar" -x --strip-components=1
  ''
  )];
}
