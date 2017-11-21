import os
import subprocess
import json
import functools
import tempfile
import shutil

# It seems to me that the correct way to do this is with some
# untrusted offloader mechanism, where a user can specify offloaders
# when they start builds, and those untrusted offloaders are used for
# fixed-output derivations.

nix_tarball_drv = "/nix/store/h0m0794x8d02hyrwkby3asajnz2s2g6n-nix-1.11.15.tar.xz.drv"

@functools.lru_cache()
def load_derivation(drv):
    data = subprocess.check_output(['nix', 'show-derivation', drv]).decode()
    return json.loads(data)[drv]

def get_drv_deps(drv):
    data = load_derivation(drv)
    return data['inputDrvs'].keys()

def is_fixed_output(drv):
    data = load_derivation(drv)
    try:
        data['outputs']['out']['hash']
        return True
    except KeyError:
        return False

def get_path_info(path):
    return json.loads(subprocess.check_output(['nix', 'path-info', '--json', path]).decode())[0]

def is_valid(drv):
    data = load_derivation(drv)
    output_path = data['outputs']['out']['path']
    # if there's no 'valid' field, it's valid
    return get_path_info(output_path).get('valid', True)

# Checking for substitutability is hard. Realising while only using
# substitutes is also hard. Since we can't do either of those, let's
# just not check for substitutability. Just try running the build once
# manually, so that anything substitutable becomes valid.
def is_substitutable(drv):
    return False
    # return subprocess.call(["nix-store", "-Q", "-j0", "--realise", drv]) == 0

def needed_fixed_output_drvs(drv, already_seen=None):
    "Outputs the unbuilt fixed-output-derivations needed to build this derivation, in topologically sorted order."
    if already_seen is None:
        already_seen = set()
    if drv in already_seen:
        return []
    already_seen.add(drv)
    if is_valid(drv):
        return []
    if is_substitutable(drv):
        return []
    ret = []
    for dep in get_drv_deps(drv):
        ret += needed_fixed_output_drvs(dep, already_seen)
    if is_fixed_output(drv):
        ret.append(drv)
    return ret

def impure_build(drv):
    # only fixed output derivations can be build impurely
    if not is_fixed_output(drv):
        raise Exception
    # no need to rebuild something which is already built
    if is_valid(drv):
        print(drv, "is already valid")
        return
    data = load_derivation(drv)
    _, name = data['outputs']['out']['path'].split('-', 1)
    # TODO should actually try to build these, I guess
    assert(all(is_valid(indrv) for indrv in data['inputDrvs'].keys()))
    workdir = tempfile.mkdtemp()
    top_outdir = tempfile.mkdtemp()
    output = os.path.join(top_outdir, "out")
    env = os.environ.copy()
    env.update(data['env'])
    env.update({'NIX_BUILD_TOP': workdir, 'out': output, 'TMPDIR': workdir})
    cmdline = [data['builder']] + data['args']
    proc = subprocess.Popen(cmdline, cwd=workdir, env=env)
    if proc.wait() != 0:
        raise Exception
    mydir = tempfile.mkdtemp()
    print("mydir", mydir)
    finalpath = os.path.join(mydir, name)
    os.rename(output, finalpath)
    hashAlgo = data['outputs']['out']['hashAlgo']
    recursive = []
    if ":" in hashAlgo:
        option, hashAlgo = hashAlgo.split(':')
        recursive = ["--recursive"]
        assert(option == 'r')
    subprocess.check_call(['nix-store', '--add-fixed', hashAlgo, finalpath] + recursive)
    shutil.rmtree(workdir)
    shutil.rmtree(top_outdir)
    shutil.rmtree(mydir)

def impurely_build_fixed_output_deps(drv):
    for drv in needed_fixed_output_drvs(drv):
        impure_build(drv)
