#!/usr/bin/env python3

import os,sys,re

FILENAME='Packages'

rgPackage=re.compile("^Package:\s+(\S+)$")
rgDepends=re.compile("^Depends:\s+(.*)$")
rgProvides=re.compile("^Provides:\s+(.*)$")

PACKAGES={}
MISSING=[]
with open(FILENAME,'r') as fp:
    package = None
    deps = None
    for line in fp.readlines():
        m = rgPackage.match(line)
        if m:
            package = m.group(1)
            PACKAGES.setdefault(package,[])
            continue
        m = rgDepends.match(line)
        if m:
            deps = []
            for dep in m.group(1).split(','):
                d = dep.strip().split(' ')
                deps.append(d[0])
            PACKAGES[package] = deps
            continue
        m = rgProvides.match(line)
        if m:
            for pkg in m.group(1).split(','):
                PACKAGES.setdefault(pkg.strip(),[]) 

for package in PACKAGES.keys():
    for dep in PACKAGES[package]:
        if dep not in PACKAGES.keys():
            MISSING.append(dep)
if set(MISSING):
    print('Missing: {}'.format(set(MISSING)))
else:
    print('ALL OK')