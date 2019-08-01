from setuptools import setup, find_packages

setup(
    name='nixutils',
    version='0.0.1',
    description='A script for downloading Nix fixed-outputs manually.',
    url='https://github.com/catern/nix-utils',
    author='catern',
    author_email='sbaugh@catern.com',
    license='MIT',
    packages=['fixedout'],
    entry_points={
        'console_scripts': ['fixedout=fixedout.fixedout:main'],
    },
)
