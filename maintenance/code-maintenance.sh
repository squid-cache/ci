#!/bin/sh

# What this script does:
##
# For a given directory containing a Squid code checkout:
#  - purge any unexpected changes to help ensure code is not polluted
#    by external fiddling.
#  - check for any repository changes to the code.
#  - run the bootstrap and source-maintenance scripts from
#    code in the branch itself. Applying any changes they cause.

# silence debug output from VCS
beQuiet="--quiet"
#beQuiet=""

# clean the current workspace
gitCleanWorkspace ()
{
#  git clean $beQuiet -df --exclude="\.BASE"
  git clean $beQuiet -xdf --exclude="\.BASE"
  git checkout $beQuiet -- .
}

abortAndExit ()
{
  git "$1" --abort 2>&1 >/dev/null
  exit 1
}

runMaintenanceScript ()
{
  script=$1
  branch=$2
  prtitle=$3

  if test -x "$script" ; then

    git checkout $beQuiet $forkPoint 2>&1 >/dev/null &&
      git checkout $beQuiet $branch 2>&1 >/dev/null &&
        gitCleanWorkspace &&
          git rebase github/$forkPoint 2>&1 >/dev/null || abortAndExit rebase

    gitCleanWorkspace &&
      $script >/dev/null || exit 1

    # only update modified files. Ignore deleted, added, etc.
    git status 2>&1 | grep "modified:" | while read a b; do git add $beQuiet $b >/dev/null; done
    git commit $beQuiet --all -m "$prtitle" >/dev/null || true
    git push $beQuiet -f --set-upstream origin +$branch 2>&1 >/dev/null || exit 1
    gitCleanWorkspace

    if test `git diff $beQuiet $forkPoint $branch 2>/dev/null | wc -l` -ne 0 ; then
      # skip if there is an existing PR already open awaiting merge
      prlist=`gh pr list -L 1 --repo squid-cache/squid --head $branch`
      if ! test -z "$prlist" ; then
        gh pr create --repo squid-cache/squid --base $forkPoint --fill
      fi
      # wait for this set of changes to complete before submittng more
      exit 0
    fi
    gitCleanWorkspace
  fi
}

(
  cd $1
  version=`basename "$1" | sed s/squid-//`

  forkPoint="v$version"
  if test -f .BASE ; then
    forkPoint=`cat .BASE`
  fi

  if ! test -d .git ; then
    echo "ERROR: missing git repository"
    exit 1;
  fi

  git fetch $beQuiet --all >/dev/null
  gitCleanWorkspace

  # Update version branch to match github
  git checkout $beQuiet $forkPoint >/dev/null

  git pull $beQuiet --all >/dev/null
  gitCleanWorkspace

  # ON CONFLICTS: abort
  git rebase github/$forkPoint >/dev/null || abortAndExit rebase
  gitCleanWorkspace

  git push $beQuiet -f --set-upstream origin +$forkPoint 2>&1 >/dev/null
  git push $beQuiet --tags github 2>&1 >/dev/null
  gitCleanWorkspace

  runMaintenanceScript ./bootstrap.sh v$version-bootstrap "Bootstrapped"
  runMaintenanceScript ./scripts/source-maintenance.sh v$version-maintenance "Source Format Enforcement"

  prlist=`gh pr list -L 1 --repo squid-cache/squid --state closed --label backport-to-v$version | wc -l`
  if test "$prlist" -ne 0; then
    echo "PENDING Backports:"
    gh pr list --repo squid-cache/squid --state closed --label backport-to-v$version

    # TODO automatically backport a merged PR based on github labels 'backport-to-vN'
    # TODO automatically remove label from PRs on successful commit+push to vN-next-backports

  fi

) 2>&1 | \
	grep -v "warning: AC_TRY_RUN called without default"
true
