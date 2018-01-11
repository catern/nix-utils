{
  nix
, perl
, pathsFromGraph
, shellcheck
, runCommand
}:

runCommand "nix-bootstrap-shar-${nix.version}-${nix.system}.sh" {
  exportReferencesGraph = [ "closure" nix ];
  buildInputs = [ perl shellcheck ];
  meta.description = "Distribution-independent Nix bootstrap self-extracting archive for ${nix.system}";
}
  ''
    storePaths=$(perl ${pathsFromGraph} ./closure)
    printRegistration=1 perl ${pathsFromGraph} ./closure > $TMPDIR/reginfo
    substitute ${./header.sh} $out --subst-var-by nix ${nix}

    shellcheck -e SC1090 $out
    chmod +x $out

    tar --create --bzip2 \
      --to-stdout \
      --verbose \
      --owner=0 --group=0 --mode=u+rw,uga+r \
      --absolute-names \
      --hard-dereference \
      --transform "s,$TMPDIR/reginfo,reginfo," \
      $TMPDIR/reginfo $storePaths >> $out
  ''
