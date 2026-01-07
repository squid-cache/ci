#!/bin/sh

# silence debug output from VCS
beQuiet="--quiet"
#beQuiet=""
verpath="$1"
version=`basename "$verpath" | sed s/squid-//`
vnext=$(( $version + 1 ))
srcbranch=v$vnext
portLabel="backport-to-v$version"

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

makeBranchOrExit ()
{
  # systemic error if this fails. abort everything.
  git checkout $beQuiet -b $1 || exit 1
}

dropBranch ()
{
  git checkout $beQuiet main || exit 1
  git branch $beQuiet -dD $1 2>/dev/null
}

dropLabel ()
{
  gh pr edit --repo squid-cache/squid $1 --remove-label $portLabel &&
  gh pr comment --repo squid-cache/squid $1 --body "queued for backport to v$version"
}

createPortPr ()
{
  portBranch="$1"

  # Reset to clean vN branch
  git checkout $beQuiet v$version 2>/dev/null &&
    gitCleanWorkspace &&
    git pull $beQuiet || exit 1

  # Create a PR to merge (if needed)
  if test `git diff --shortstat github/$srcbranch $portBranch 2>/dev/null | wc -l` -ne 0 ; then
    git push $beQuiet -u origin +$portBranch >/dev/null || exit 1
    # skip if there is an existing PR already open awaiting merge
    prlist=`gh pr list -L 1 --repo squid-cache/squid --head $portBranch | wc -l`
    if test "$prlist" -eq 0 ; then
      gh pr create --repo squid-cache/squid --base v$version --title "v$version Next Backports" --body "" || true
      dropLabel $prnum
    fi
  fi
}

# Ensure we have the latest repository state available
git fetch $beQuiet --all || exit 1
git pull $beQuiet || exit 1

# Find backports to attempt:
prlist=`gh pr list -L 1 --repo squid-cache/squid --state closed --label $portLabel | wc -l`
if test "$prlist" -ne 0; then
  gh pr list --repo squid-cache/squid --state closed --label $portLabel | while read prnum text; do
    # find a commit in $srcbranch with " (#$prnum)" subject suffix
    git log --oneline github/$srcbranch --grep=" (#$prnum)\$" | while read sha rest; do
      portBranch="v$version-backport-pr$prnum"
      makeBranchOrExit $portBranch
      msg=`git cherry-pick $beQuiet $sha 2>&1 || (abortAndContinue cherry-pick ; dropBranch $portBranch)`
      if ! test -z "$msg" ; then
        echo "$msg" | grep -E "^error:"
        unlabel=`echo "$msg" | grep -E "The.previous.cherry-pick.is.now.empty"`
        test -z "$unlabel" && (createPortPr $portBranch || exit 1)
        test -z "$unlabel" || dropLabel $prnum
      fi
      gitCleanWorkspace
    done
  done
  git push $beQuiet 2>&1 >/dev/null || true
fi
