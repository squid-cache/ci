#!/usr/bin/env python3

SUPPORTED_VERSIONS=[6]
BETA_VERSIONS=[7]

from subprocess import check_output
import json

# get releases. Rely that they are in release order
releases = json.loads(
    check_output(
        'gh -R squid-cache/squid release list --exclude-drafts -L 3000 --json name,tagName,createdAt,isPrerelease'.split(" ")
    )
)

major_releases=sorted(list(set(map(lambda x: x['tagName'].split('_')[1], releases))))
major_releases.remove('RELEASES')
major_releases=sorted(map(int,major_releases),reverse=True)

def render_release(release):
    releaseDate=release['createdAt'].split('T')[0]
    releaseUrl=f"https://github.com/squid-cache/squid/releases/tag/{release['tagName']}"
    return f"<li><a href='{releaseUrl}'>{release['name']}</a> (released {releaseDate})"

print("<?php")
print("$supported_versions=<<<EOF")
for r in SUPPORTED_VERSIONS:
    for release in releases:
        if release['tagName'].split('_')[1] == str(r):
            print(render_release(release))
            break
print("EOF;")

print("$beta_versions=<<<EOF")
for r in BETA_VERSIONS:
    for release in releases:
        if release['tagName'].split('_')[1] == str(r):
            print(render_release(release))
            break
print("EOF;")

print("$older_versions=<<<EOF")
for r in major_releases:
    if r in SUPPORTED_VERSIONS + BETA_VERSIONS:
        continue
    for release in releases:
        if release['tagName'].split('_')[1] == str(r):
            print(render_release(release))
            break
print("EOF;")
print("?>")
