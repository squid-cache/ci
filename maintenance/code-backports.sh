#!/bin/sh

# silence debug output from VCS
beQuiet="--quiet"
#beQuiet=""
verpath="$1"
version=`basename "$verpath" | sed s/squid-//`
vnext=$(( $version + 1 ))
srcbranch=v$vnext

cd $verpath

# Dev branch does not receive backports
test -f .BASE && exit 0

# clean the current workspace
gitCleanWorkspace ()
{
  git clean $beQuiet -xdf --exclude="\.BASE"
  git checkout $beQuiet -- .
}

if ! test -d .git ; then
  echo "ERROR: missing git repository"
  exit 1;
fi
if ! test -d ../squid-$vnext ; then
  echo "ERROR: missing git repository to backport from"
  exit 1;
fi
if test -e ../squid-$vnext/.BASE ; then
  srcbranch=`cat ../squid-$vnext/.BASE`
fi

abortAndExit ()
{
  git $1 --abort 2>&1 >/dev/null
  exit 1
}

abortAndContinue ()
{
  git $1 --abort 2>&1 >/dev/null || true
}

# Prepare backports branch for updates
git checkout $beQuiet v$version-next-backports 2>/dev/null &&
  gitCleanWorkspace &&
    git fetch $beQuiet --all &&
    git pull $beQuiet origin v$version-next-backports &&
    git rebase origin/v$version 2>/dev/null &&
    git push -u origin +v$version-next-backports || abortAndExit rebase

# Find backports to attempt:
prlist=`gh pr list -L 1 --repo squid-cache/squid --state closed --label backport-to-v$version | wc -l`
if test "$prlist" -ne 0; then
  gh pr list --repo squid-cache/squid --state closed --label backport-to-v$version | while read prnum text; do
    # find a commit in $srcbranch with " (#$prnum)" subject suffix
    git log --oneline github/$srcbranch --grep=" (#$prnum)\$" | while read sha rest; do
      msg=`git cherry-pick $beQuiet $sha 2>&1 || abortAndContinue cherry-pick`
      if ! test -z "$msg" ; then
        echo "$msg" | grep -E "^error:"
        unlabel=`echo "$msg" | grep -E "The.previous.cherry-pick.is.now.empty"`
        if ! test -z "$unlabel" ; then
            gh pr edit --repo squid-cache/squid $prnum --remove-label backport-to-v$version &&
            gh pr comment --repo squid-cache/squid $prnum --body "queued for backport to v$version"
        fi
      fi
      gitCleanWorkspace
    done
  done
  git push $beQuiet 2>&1 >/dev/null || true

  # Create a PR to merge (if needed)
  if test `git diff --shortstat github/$srcbranch v$version-next-backports 2>/dev/null | wc -l` -ne 0 ; then
    git push $beQuiet -u origin +v$version-next-backports >/dev/null || exit 1
    # skip if there is an existing PR already open awaiting merge
    prlist=`gh pr list -L 1 --repo squid-cache/squid --head v$version-next-backports | wc -l`
    if test "$prlist" -eq 0 ; then
      gh pr create --repo squid-cache/squid --base v$version --title "v$version Next Backports" --body "" || true
    fi
  fi

fi
