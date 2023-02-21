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
  git checkout -- .
}

runMaintenanceScript ()
{
  script=$1
  branch=$2
  prtitle=$3

  if test -x $script ; then

    git checkout $beQuiet $forkPoint &&
      git checkout $beQuiet $branch &&
        gitCleanWorkspace &&
          git rebase github/$forkPoint || ( git rebase --abort ; exit 1 )

    gitCleanWorkspace &&
      $script || exit 1

    # only update modified files. Ignore deleted, added, etc.
    git status 2>&1 | grep "modified:" | while read a b; do git add $b; done
    git commit $beQuiet --all -m "$prtitle" || true
    git push $beQuiet -f --set-upstream origin +$branch || exit 1
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
  if [ -f .BASE ]; then
    forkPoint=`cat .BASE`
    echo "forkPoint=$forkPoint"
  fi

  if [ ! -d .git ]; then
    echo "ERROR: missing git repository"
    exit 1;
  fi

  git fetch $beQuiet --all
  gitCleanWorkspace

  git pull $beQuiet --all
  gitCleanWorkspace

  # Update version branch to match github
  git checkout $beQuiet $forkPoint
  # ON CONFLICTS: abort
  git rebase github/$forkPoint || ( git rebase --abort ; exit 1 )
  gitCleanWorkspace

  git push $beQuiet -f --set-upstream origin +$forkPoint 2>&1
  git push $beQuiet --tags github
  gitCleanWorkspace

  runMaintenanceScript ./bootstrap.sh v$version-bootstrap "Bootstrapped"
  runMaintenanceScript ./scripts/source-maintenance.sh v$version-maintenance "Source Format Enforcement"

  prlist=`gh pr list -L 1 --repo squid-cache/squid --state closed --label backport-to-v$version | wc -l`
  if test "$prlist" -ne 0; then
    echo "PENDING Backports:"
    gh pr list --repo squid-cache/squid --state closed --label backport-to-v5

    # TODO automatically backport a merged PR based on github labels 'backport-to-vN'
    # TODO automatically remove label from PRs on successful commit+push to vN-next-backports

  fi

) 2>&1 | \
	grep -v "warning: AC_TRY_RUN called without default" | \
	grep -v "bootstrapping complete"
true
