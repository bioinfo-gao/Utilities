人生不如意之事十之八九，合并分支往往也不是一帆风顺的。

准备新的feature1分支，继续我们的新分支开发：

$ git switch -c feature1
Switched to a new branch 'feature1'
修改readme.txt最后一行，改为：

Creating a new branch is quick AND simple.
在feature1分支上提交：

$ git add readme.txt

$ git commit -m "AND simple"
[feature1 14096d0] AND simple
 1 file changed, 1 insertion(+), 1 deletion(-)
切换到master分支：

$ git switch master
Switched to branch 'master'
Your branch is ahead of 'origin/master' by 1 commit.
  (use "git push" to publish your local commits)


现在，master分支和feature1分支各自都分别有新的提交，变成了这样：

这种情况下，Git无法执行“快速合并”，只能试图把各自的修改合并起来，但这种合并就可能会有冲突，我们试试看：

git merge feature1

Auto-merging git_Advanced/branchfile.txt
CONFLICT (content): Merge conflict in git_Advanced/branchfile.txt
Automatic merge failed; fix conflicts and then commit the result.

git status也可以告诉我们冲突的文件：


我们可以直接查看 vim readme.txt的内容：

Git is a distributed version control system.
Git is free software distributed under the GPL.
Git has a mutable index called stage.
Git tracks changes of files.
<<<<<<< HEAD
Creating a new branch is quick & simple.
=======
Creating a new branch is quick AND simple.
>>>>>>> feature1



我们修改如下后保存：

Git is a distributed version control system.
Git is free software distributed under the GPL.
Git has a mutable index called stage.
Git tracks changes of files.
Creating a new branch is quick and simple.
再提交：

$ git add readme.txt 
$ git commit -m "conflict fixed"
[master cf810e4] conflict fixed


用带参数的git log也可以看到分支的合并情况：

$ git log --graph --pretty=oneline --abbrev-commit
*   cf810e4 (HEAD -> master) conflict fixed
|\  
| * 14096d0 (feature1) AND simple
* | 5dc6824 & simple
|/

最后，删除feature1分支：

git branch -d feature1


# === 如果报错
git switch master

fatal: cannot switch branch while rebasing

Consider "git rebase --quit" or "git worktree add".

~/Code/Linux_and_Cluster_for_Omics/git_Advanced :  

在 $\text{Rebase}$ 过程中，$\text{Git}$ 会暂停在每一个冲突点，直到您告诉它如何处理。如果您解决了冲突，但没有执行下一步的 git rebase --continue 或 git add，$\text{Git}$ 就会认为 $\text{Rebase}$ 还在进行中，因此拒绝切换分支。

git add .
git rebase --continue               #<<<===========================

gao@ DESKTOP-C8OKE65  23:27 $ git rebase --continue
[detached HEAD 5802097] AND simple
 1 file changed, 5 insertions(+), 1 deletion(-)
Successfully rebased and updated refs/heads/master.

# git rebase --abort 则是放弃merge



