"""The main useful functions in this file are
build_drv_with_impure_fixouts and realise_path_with_impure_fixouts.

This file uses the "nix show-derivation" and "nix path-info"
subcommands from Nix 1.12.

It seems to me that the right way to do what these functions do, is
with some untrusted offloader mechanism, whereby a user can specify
offloaders when they start builds, and those untrusted offloaders are
used for fixed-output derivations. This should be built into Nix.

"""

import os
import subprocess
import json
import functools
import tempfile
import shutil

@functools.lru_cache()
def load_derivation(drv):
    data = subprocess.check_output(['nix', 'show-derivation', drv]).decode()
    return json.loads(data)[drv]

@functools.lru_cache()
def get_path_info(path):
    return json.loads(subprocess.check_output(['nix', 'path-info', '--json', path]).decode())[0]

def get_deriver(path):
    return get_path_info(path)['deriver']

def is_fixed_output(drv):
    data = load_derivation(drv)
    try:
        data['outputs']['out']['hash']
        return True
    except KeyError:
        return False

def all_output_paths(drv):
    data = load_derivation(drv)
    return [output['path'] for output in data['outputs'].values()]

def input_drvs_with_paths(drv):
    data = load_derivation(drv)
    ret = []
    for input_drv in data['inputDrvs']:
        wanted_paths = []
        dep_data = load_derivation(input_drv)['outputs']
        for output in data['inputDrvs'][input_drv]:
            wanted_paths.append(dep_data[output]['path'])
        ret.append((input_drv, wanted_paths))
    return ret

def ensurePath(path):
    """This is an indirect way to call ensurePath in store-api.hh

    Essentially, this does:
    if is_valid(path):
      return True
    try_substitute(path)
    return is_valid(path)

    """
    args = ["nix-instantiate",
            "--read-write-mode",
            "--eval",
            "--expr",
            "__storePath {}".format(path)]
    return subprocess.run(args, stdout=subprocess.DEVNULL).returncode == 0

def build_drv_with_impure_fixouts(drv, wanted_paths=None):
    "Build this deriver, passing off any fixouts we need to build off to a local impure builder."
    # if wanted paths is not specified, we want everything
    if wanted_paths is None:
        wanted_paths = all_output_paths(drv)
    # no need to build if we can substitute all the specifically
    # wanted paths that are output by this derivation.
    if all(ensurePath(path) for path in wanted_paths):
        return wanted_paths
    # We have to build after all. wanted_paths is now irrelevant
    # because the derivation will build every output anyway.
    # Frist, to build this derivation, we need to realise all the deriver's input paths.
    for input_drv, input_wanted_paths in input_drvs_with_paths(drv):
        build_drv_with_impure_fixouts(input_drv, wanted_paths=input_wanted_paths)
    # all the inputs are valid, so now we can perform the build.
    if is_fixed_output(drv):
        # if this derivation is fixout, then we impurely build it.
        impure_build(drv)
    else:
        # otherwise, just build it normally
        build(drv)
    return wanted_paths

def realise_path_with_impure_fixouts(path):
    "Realise this path, passing off any fixouts we need to build off to a local impure builder."
    # if we can substitute the path, or it's already valid, we're already done
    if ensurePath(path):
        return
    # okay, this path isn't already valid and we can't substitute it.
    # so we need to build the path, using its deriver.
    build_drv_with_impure_fixouts(get_deriver(path))

class BuildFailedError(Exception):
    pass

def impure_build(drv):
    "Impurely build this derivation in the current environment and add it to the store."
    # only fixed output derivations can be build impurely
    if not is_fixed_output(drv):
        raise Exception
    output_paths = all_output_paths(drv)
    if len(output_paths) != 1:
        raise Exception("doesn't support multiple outputs")
    output_path = output_paths[0]
    data = load_derivation(drv)
    _, name = data['outputs']['out']['path'].split('-', 1)
    # all my inputs need to be valid
    if not all(ensurePath(indrv) for indrv in data['inputDrvs'].keys()):
        raise Exception("Not all my inputs are valid.")
    workdir = tempfile.mkdtemp()
    top_outdir = tempfile.mkdtemp()
    output = os.path.join(top_outdir, "out")
    env = os.environ.copy()
    env.update(data['env'])
    env.update({'NIX_BUILD_TOP': workdir, 'out': output, 'TMPDIR': workdir})
    cmdline = [data['builder']] + data['args']
    proc = subprocess.Popen(cmdline, cwd=workdir, env=env)
    if proc.wait() != 0:
        raise BuildFailedError
    mydir = tempfile.mkdtemp()
    finalpath = os.path.join(mydir, name)
    os.rename(output, finalpath)
    hashAlgo = data['outputs']['out']['hashAlgo']
    recursive = []
    if ":" in hashAlgo:
        option, hashAlgo = hashAlgo.split(':')
        recursive = ["--recursive"]
        assert(option == 'r')
    ending_path = subprocess.check_output(['nix-store', '--add-fixed', hashAlgo, finalpath] + recursive).strip().decode()
    if output_path != ending_path:
        print("Expected path:", output_path)
        print("Does not match path we ended up with:", ending_path)
        print("workdir", workdir)
        print("top_outdir", top_outdir)
        print("mydir", mydir)
        raise Exception
    shutil.rmtree(workdir)
    shutil.rmtree(top_outdir)
    shutil.rmtree(mydir)

def build(drv):
    "Build this derivation using normal nix-store --realise"
    subprocess.run(['nix-store', '--realise', drv], check=True)

if __name__ == "__main__":
    import sys
    path = sys.argv[1]
    if path.endswith(".drv"):
        print("Assuming", path, "is a derivation, invoking build_drv_with_impure_fixouts")
        for output in build_drv_with_impure_fixouts(path):
            print(output)
    else:
        print("Assuming", path, "is a path, invoking realise_path_with_impure_fixouts")
        realise_path_with_impure_fixouts(path)
