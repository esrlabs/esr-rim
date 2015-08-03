# RIM - Multi git tool

RIM lets you work with multiple git repositories from within one single git repository.

# RIM User Guide

> From RIM version 1.1.4 it is no more necessary to set the global git autocrlf option to false on Windows platforms. If you don't have other reasons you might want to set it back to the recommended value (which is true).

## Concept

RIM is used to synchronize software modules (let's call them library modules) which are git repositories into a project specific git repository. As long as you don't need to upgrade or modify one of the synchronized library modules, you don't need RIM. In other words: if somebody else in the project takes care of the library module synchronization, you can work with one single GIT repository without worrying about RIM or library module synchronization.
When RIM has synchronized a specific version of a library module into your project GIT, it records the source of the library module in the local module directory within a .riminfo file.

## Use Cases

* Check the status of your local commits (dirty or clean), which lists dirty modules just in case  (rim status -d)
* Add a new library module to your project git (rim sync -c)
* Upgrade an existing library module (rim sync)
* Upload modifications of a library module (rim upload)

## Terms

* __Project__: a set of modules plus project specific code
* __Project Git__: a single git repository which contains all code belonging to the project (including the code from modules)
* __Module__: a unit of code which can be added to a project individually
* __Module Git__: git repository holding a module
* __Module Dir__: directory in the project workspace where the module is located
* __.riminfo File__: file contained in a Module Dir holding rim specific information
* __.rim Dir__: directory in a project root dir holding rim specific information

## Installation

Install and update RIM via the gem package mechanism:

    > gem install esr-rim

## Getting started in your project

There's not a lot you have to do to introduce rim into your project. The most important step is:
Before using rim add the pattern

    .rim/

to your project's `.gitignore` and commit this change.

## Synchronize your project git with a module git

Whenever you decide to use rim to synchronize the content of a library module with your project Git you have to do an initial synchronization step:

    > rim sync -c -u <gerrit path> -r <branch or tag> -m <message header> -i <ignore patterns> <local directory>

which actually means the following:

1. The option -c indicates that we want to create a new rim module folder at the local specified with <local directory>. If <local directory> is already part of a module folder synchronized this will result in an error.
2. The mandatory option -u specifies the remote repository holding the module's content (the Module Git)
3. The mandatory option -r specifies the revision to synchronize with, typically a branch (such as master) or a specific tag.
4. The option -m helps you to define a header message text for the commits of rim. This option is important if your project requires a certain Git message header pattern.
5. The option -i can be used to specify patterns of files/folders which are specific only to this project and are not expected or allowed to be part of the Module Git. Files or folders matching to one of the patterns aren't removed when synchronizing content and wont't be forwarded to the Module Git when uploading.

### Example:

    > rim sync -c -u libraries/modules/projectA -r master -m "PROJ-123/ThHe: integrated projectA module" -i CMakeLists.txt projectA

lets rim synchronize the state of branch master from the remote repository `ssh://gerrit/libraries/modules/projectA` into the relative folder projectA and won't touch files named CMakeLists.txt that are already within this folder. The corresponding commit message header will be "PROJ-123/ThHe: integrated projectA module"

## The magic rim integration branch

A call to rim sync actually does not change anything on the current branch in your Project Git. In fact all changes are committed to a special branch - the rim integration branch. It s managed automatically and named by adding the prefix 'rim/' to your current branch's name. So if your working branch is called 'master' all changes of rim sync will be commited to the branch 'rim/master'.
The rim integration branch will be automatically created if it is not existing or the latest remote revision is not (transitive) parent of the branch. In this case the branch will be created on the latest clean revision that only has clean parent revisions.
To get the changes commited to the rim integration branch into your working branch you simply rebase using git, e.g.:

    > git rebase rim/master

*Never change (e.g. squash or amend) a commit created by rim after rebasing! This could cause conflicts on the .riminfo file on subsequent rebasing.*

## Synchronize again

The rim tool stores all the settings given by the initial rim sync call within a .riminfo file in the root of the module folder.

*This file shall not be changed manually and it will cause rim to ignore the content if it has been touched.*

Unless you intentionally want to change the synchronization settings for a specific module you never have to specify those settings in a subsequent call to rim sync again. So once you've integrated a module with rim you're able to resynchronize the contents of module folders using just:

    > rim sync -m <message header> <local directory>

This will cause rim to read out the settings from the module's .riminfo file and do exactly the same as described for the initial synchronization step above. Note that it makes sense to think about the correct message header (although it's optional). If there were changes to the module's revision stored in the .riminfo file (e.g. the specified branch has moved in the module Git) then you will find the appropriate commit in the corresponding rim integration branch. Otherwise rim will indicate that there were no changes and you're done.
If you want to change the configuration of a module integrated with rim (e.g. you want to integrate a certain revision) you can simply call rim sync by specifying all options you want to change:

    > rim sync -u <gerrit path> -r <branch or tag> -m <message header> -i <ignore patterns> <local directory>

This means:

1. If you want to change the remote repository specify the -u option as described above
2. Use the -r option if you need another branch or tag to synchronize with
3. If you want to change the list of files or folders to ignore then specify the new list using -i.
The -i option allows you only to replace the ignore list completely. So to append a new pattern to this list don't forget to also specify the previous entries.

### Example:

    > rim sync -r release_1.1.2 projectA

lets rim commit the content of the tag or branch release_1.1.2 (same repository, same ignore patterns, automatically created commit message) to the integration branch.

## Modify and commit files in a Module Directory

If you're owner of a library module and thus are authorized to do changes in the module's sources rim supports you in doing that from within your Project Git: whenever you have the need of modifying files in a module directory you can do that in your project directory. Make your changes as needed and commit them to your local project repository.

*You cannot simply push the changes to the remote repository. The remote server will reject your direct push because module folders are touched and thus got "dirty". This behaviour ensures that no unintended modifications of library modules can creep into your project code.*

So if you're not allowed to commit changes to a library module: reset your branch to a clean rim status, otherwise you will never be able to push anything again.

### But how can a module owner get the local changes to the library module Git?

Supposed you are authorized and you now want to publish your module changes (i.e. push them to the remote project repository) the way is as follows:

1. Use rim to upload your changes to the review branch in Gerrit. 
2. As soon as the review is successful and the modifications are applied to your module Git you use rim sync to resynchronize the changes into your local repository again – after the rebase and if you did no further changes your module is "clean" again.
3. Now that the module has reached a clean rim status you can commit your change to the remote project repository.

In the next sections we will have a more detailled look on integrating changes to library modules.

### Prepare your repository for work

Before using rim to upload changes from the Project Git to a Module Git you should prepare your local project repository:

* Use curl or scp to inject the Gerrit commit-msg hook (which adds automatically Gerrit-ChangeIds to your message) using one of the following lines:

~~~
> curl -Lo <local path to project git>/.git/hooks/commit-msg http://gerrit/tools/hooks/commit-msg
~~~

or

    > scp -p gerrit:hooks/commit-msg <local path to project git>/.git/hooks/

* Make sure that the downloaded hook file is executable:

~~~
> chmod u+x <local path to project git>/.git/hooks/commit-msg
~~~

### Upload to the review branch

To track the quality of module changes all modifications to a library module have to be reviewed (using Gerrit). So similar to the workflow with repo all changes are first committed to the corresponding review branch. rim helps you in forwarding your module changes to Gerrit:

    > rim upload <local directory>

With this command rim collects your changes to the specific module directory and commits a copy of the content to the corresponding branch that you specified for the module. So if you have specified master as the target revision of your module then your changes will be pushed to the refs/for/master branch (just like repo does).

*Only files are uploaded which do not match one the patterns specified in the rim ignore list (-i option of rim sync). So to avoid upload of project-only files specify them in the ignore list.*

*You can upload changes only if you specified a branch (-r option of rim sync) for your module, rim refuses uploads for tag or SHA1 revisions.*

### Resynchronize your reviewed changes from the Module Git

If you have a merciful reviewer or he just likes what you did then your changes will be submitted to the remote branch of the Module Git. If your intention was just to submit this change to your Module Git then your work is done. But normally you also want to get ahead in your project. Therefore you still want to push the commited and reviewed changes also to your remote project repository. This can now easily be done by using rim sync:

* Synchronize with curren revision.

~~~
> rim sync -m <message header> <local directory>
~~~

* Rebase on rim integration branch

~~~
> git rebase rim/<current branch>
~~~

as described earlier. Proposed you haven't changed anything in your module since your last rim upload this rebase should have simply replaced the module's .riminfo file and thus made this folder clean again.

### Correct rejected changes

In case your modifications are rejected by the reviewer you can simply adjust your code and upload your changes again by doing the following steps:

* Correct your code corresponding to the results of the review. But now commit the changes by amending your previous commit:

~~~
> git commit --amend
~~~

This will keep the correct ChangeId for the corresponding Gerrit in your commit and it will avoid a second "dirty" commit in your project repository.

* Upload the changes again with rim upload as described above and wait for the next Gerrit review result.
