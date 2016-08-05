# Release Process

| Section        | Value                                                         |
|----------------|------------------------------------|
| DIP:           | 75                                 |
| Status:        | Implemented                        |
| Author:        | David Soria Parra and Martin Nowak |

## Abstract

The current release process of DMD, Druntime and Phobos (from now on referred to as "release package"), is done on a "done when it's done" basis. This DIP proposes a time-based release schedule. This allows:

-   reduced times to get bugfixes out
-   a clear way of managing backwards compatibility
-   a more predictable release schedule for packagers
-   cleaner responsibilities
-   assurance to developers regarding timeliness of release of their contributions
-   synchronization with releases processes of major distributions

In addition the DIP proposes the idea of **Release Managers**, who are responsible for a timely release.

## Release Process

We propose to introduce **bugfix versions** and **feature versions**. A **feature version** may contain new features, language changes, and deprecations. For every release version the minor part of the version is incremented: 2.066, 2.067, ... A **bugfix version** is based on a feature version and contains only bugfixes and neither new features, nor deprecations of other features or library changes. Bugfix versions are for example: 2.066.1, 2.066.2, etc. There is only one supported version at a time, but release managers are free to release additional bugfix versions when needed.

### Schedule

A bugfix version is released *every month*. A feature version is released every 2 months. Releases should happen on the first Saturday of the month. Two weeks before a feature release *stable* is branched off *master*. No new features are integrated into *stable*.

Example schedule:

-   Dec 14th: Branch cut (master becomes stable)
-   Jan 1st: 2.069
-   Feb 1st: 2.069.1
-   Feb 14th: Branch cut (master becomes stable)
-   Mar 1st: 2.070
-   Apr 1st: 2.070.1

### Support and Packages

Only the most recent version is supported. Distributions are free to backport what is needed. In addition Release Managers can decided to release additional fix versions if needed. The release manager offer the source code of the release as a tarball (\*.tar.gz, \*.tar.xz) as well as a Windows version. All other formats are left to packagers and should be preferable automized.

### Branching strategy

**TL;DR** Safe fixes should **always** go into stable, all the time.

------------------------------------------------------------------------

There are two branches: master and stable. Two weeks before a feature release the master branch becomes stable. All subsequent *bugfix* versions are tagged off the stable branch. New features go to master, which will become the next major version. Stable is regularly merged back into master to ensure that bugfixes make it into master.

Branching Figure:

```
    ----- master --o--------o------------------------
     \            /        /                     \
      stable ---------------------------------    stable
           \           \
           TAG 2.069  TAG 2.069.1
```

When compared to cherry-picking fixes from master, this allows us to properly track which releases contain a particular fix. It also causes less merge conflicts b/c no duplicated commits must be merged and reduces the work to identify commits on master that need to be cherry-picked. The downside is that github doesn't allow to change the target branch of a PR. So if a PR inadvertently targets master, it will have to be rebased onto stable and a new PR must be opened.

### Security Management

Release managers should keep track of security related bugs. They are responsible for following a *responsible disclosure policy* for D. This means, set an expected fix date and communicate the date with the original vulnerability reporter. Contact packages to get ready to publish packages at the given date and obtain an CVE if necessary. Upon release date they notify the packagers and write an announcement explaining the vulnerability and include the reporter if desired. That way we ensure a smooth handling of security problems in line with standard community processes.

## Release manager

There are always two or more release managers. This allows the releases being independent from a single point of failure (vacation, personal matters, etc), and allows a smooth ramp-up for release managers. Release managers are responsible for releasing the *release package* on time. They ensure that bugfix releases do not contain any backwards compatibilities and maintain the changelog. Release managers are free to remove features or fixes when necessary. Release managers are able to merge features and bugfixes on github. They are to provide a GPG signed tarball and a feature. Release managers are appointed by Walter and Andrei.

## Copyright

Copyright (c) 2016 by the D Language Foundation

Licensed under [Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/legalcode.txt)
