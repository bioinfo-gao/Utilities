https://liaoxuefeng.com/books/git/introduction/index.html

# ========================================= 
首先这里再明确一下，所有的版本控制系统，其实只能跟踪文本文件的改动，比如TXT文件，网页，所有的程序代码等等，Git也不例外。版本控制系统可以告诉你每次的改动，比如在第5行加了一个单词“Linux”，在第8行删了一个单词“Windows”。而图片、视频这些二进制文件，虽然也能由版本控制系统管理，但没法跟踪文件的变化，只能把二进制文件每次改动串起来，也就是只知道图片从100KB改成了120KB，但到底改了啥，版本控制系统不知道，也没法知道。

不幸的是，Microsoft的Word格式是二进制格式，因此，版本控制系统是没法跟踪Word文件的改动的，前面我们举的例子只是为了演示，如果要真正使用版本控制系统，就要以纯文本方式编写文件。

因为文本是有编码的，比如中文有常用的GBK编码，日文有Shift_JIS编码，如果没有历史遗留问题，强烈建议使用标准的UTF-8编码，所有语言使用同一种编码，既没有冲突，又被所有平台所支持

# ========================================= 
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

	modified:   readme.txt

no changes added to commit (use "git add" and/or "git commit -a")

# ========================================= 

第一天上班时，已经记不清上次怎么修改的readme.txt，所以，需要用git diff这个命令看看：

# ========================================= 

diff --git a/readme.txt b/readme.txt
$ git diff readme.txt 
index 46d49bf..9247db6 100644
--- a/readme.txt
+++ b/readme.txt
@@ -1,2 +1,2 @@
-Git is a version control system.
+Git is a distributed version control system.
 Git is free software.

# ========================================= 
# 我的个人观察，"git reflog" better than "git log" , reflog ==> "reference of log"
# 信息多， 结构清晰，
# ========================================= 
git reflog
6b61aa0 (HEAD -> master, origin/master, origin/HEAD) HEAD@{0}: commit: git_advanced
7c50a2a HEAD@{1}: commit: git lfs
35d1959 HEAD@{2}: commit: remove .gitkeep files
015535e HEAD@{3}: commit: restore
0505634 HEAD@{4}: pull --tags origin master (finish): returning to refs/heads/master
0505634 HEAD@{5}: pull --tags origin master (pick): backup
3469ef3 HEAD@{6}: pull --tags origin master (start): checkout 3469ef3d5afc35e4a992ebd944daed74fedb4ea7
acd19fd HEAD@{7}: commit: backup
0260294 HEAD@{8}: commit: cdroom repair
67169c5 HEAD@{9}: pull --tags origin master: Fast-forward
5003f7c HEAD@{10}: commit: grub crypt
7b98427 HEAD@{11}: commit: double system boot
0e54586 HEAD@{12}: commit: grub mimic /root
e98644d HEAD@{13}: commit: grub
9efeef3 HEAD@{14}: commit: runlevel
113fca9 HEAD@{15}: commit: logrotate
f023a0b HEAD@{16}: commit: log
# ========================================= 
gao@ DESKTOP-C8OKE65  15:33 $ git log
commit 6b61aa013fa8848b868c6ccc7fc64cd38b74f445 (HEAD -> master, origin/master, origin/HEAD)
Author: WSL_Oracle <bioinfo.gao@gmail.com>
Date:   Wed Dec 3 15:34:10 2025 -0500

    git_advanced

commit 7c50a2a590f1d56ed4411f65f2fe35e358bf4037
Author: WSL_Oracle <bioinfo.gao@gmail.com>
Date:   Mon Dec 1 14:12:59 2025 -0500

    git lfs

commit 35d1959eabde38851fe0da0cccb3b69fc0f839fa
Author: WSL_Oracle <bioinfo.gao@gmail.com>
Date:   Mon Dec 1 01:03:46 2025 -0500

    remove .gitkeep files
# =========================================  
# 如果git status告诉你有文件被修改过，用git diff可以查看修改内容。
# =========================================  
On branch master
Your branch is up to date with 'origin/master'.

You are in a sparse checkout with 41% of tracked files present.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   git_Advanced/1_git_advanced_tutorial

no changes added to commit (use "git add" and/or "git commit -a")
# ========================================= 
# git log --pretty=oneline 比git log 好一点，但远不如 git reflog
# ========================================= 
git log --pretty=oneline
6b61aa013fa8848b868c6ccc7fc64cd38b74f445 (HEAD -> master, origin/master, origin/HEAD) git_advanced
7c50a2a590f1d56ed4411f65f2fe35e358bf4037 git lfs
35d1959eabde38851fe0da0cccb3b69fc0f839fa remove .gitkeep files
015535e0e0b6bbcc980e98f3f4d0888507c1d1f1 restore

# ========================================= 
首先，Git必须知道当前版本是哪个版本，在Git中，用HEAD表示当前版本，也就是最新的提交1094adb...
（注意我的提交ID和你的肯定不一样），上一个版本就是HEAD^，上上一个版本就是HEAD^^，
然往上100个版本写100个^比较容易数不过来，
所以写成HEAD~100

# HEAD   HEAD^  HEAD^^  HEAD~100 

# ========================================= 
# 我的观察是 HEAD HEAD@{0} HEAD@{1} HEAD@{2} 
# ========================================= 

6b61aa0 (HEAD -> master, origin/master, origin/HEAD) HEAD@{0}: commit: git_advanced
7c50a2a HEAD@{1}: commit: git lfs
35d1959 HEAD@{2}: commit: remove .gitkeep files
015535e HEAD@{3}: commit: restore

# ========================================= 
# ============版本回退=============== 
# ========================================= 
$ git reset --hard HEAD^
HEAD is now at e475afc add distributed

git reset --soft dcd36a8

# ========================================= # ========================================= 
# --hard参数有啥意义？--hard会回退到上个版本的已提交状态，
# --soft会回退到上个版本的未提交状态，
# --mixed会回退到上个版本已添加但未提交的状态。
# 现在，先放心使用--hard 
# ========================================= # ========================================= 


# ========================================= 
# 用git log再看看现在版本库的状态
# ========================================= 
# 只要上面的命令行窗口还没有被关掉，你就可以顺着往上找啊找啊，找到那个append GPL的commit id是1094adb...，于是就可以指定回到未来的某个版本：

# $ git reset --hard 1094a
# HEAD is now at 83b0afe append GPL
# 版本号没必要写全，前几位就可以了，Git会自动去找。当然也不能只写前一两位，因为Git可能会找到多个版本号，就无法确定是哪一个了。


# ========================================= 
# 快捷键会根据编辑器底部状态栏显示的当前语言模式来选择正确的注释符号。
# 如果文件是 Python，它使用 #。
# 如果文件是 JavaScript/C++/Java，它使用 //。
# 如果文件是 Assembly (汇编)、Clojure、INI 或某些配置文件，它可能会使用 ;。
# C language These comments begin with /* and end with */
# C language These comments following // on that line, at  the end of the line, is considered a comment.
# e.g. int x = 10; // This is a single-line comment explaining the variable 'x'.
# =========================================


# ========================================= 
# 令git reflog用来记录你的每一次命令：
# ========================================= 

# 穿梭前，用git log可以查看提交历史，以便确定要回退到哪个版本。
# 要重返未来，用git reflog查看命令历史，以便确定要回到未来的哪个版本。

# ========================================= 
在你准备提交前，一杯咖啡起了作用，你猛然发现了stupid boss可能会让你丢掉这个月的奖金！

既然错误发现得很及时，就可以很容易地纠正它。
你可以删掉最后一行，手动把文件恢复到上一个版本的状态。

在未删除前 如果用git status查看一下：
# ========================================= 
$ git status
On branch master
Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

	modified:   readme.txt

no changes added to commit (use "git add" and/or "git commit -a")
# ========================================= 
删除后 如果用git status查看一下：
# ========================================= 
$ git status
On branch master
No changes 

# ========================================= 
也可以不删除，直接丢弃工作区的修改
注意1）加上路径，
注意2）可以只丢弃这一个文件的修改

git checkout -- git_Advanced/testfile.txt

# ========================================= 
git checkout -- file命令中的--很重要，没有--，
就变成了“切换到另一个分支”的命令，
我们在后面的分支管理中会再次遇到git checkout命令。
# ========================================= 

现在假定是凌晨3点，你不但写了一些胡话，还git add到暂存区了：


# ========================================= 

Git同样告诉我们，用命令
git reset HEAD <file>
可以把暂存区的修改撤销掉（unstage），重新放回工作区：

git reset HEAD git_Advanced/testfile.txt

注意，这只是放回工作区，并没有撤销修改

# ========================================= 
# ========================================= 
# ========================================= 
# git reset命令既可以回退版本， <<======
# 也可以把暂存区的修改回退到工作区。 <<======
# 当我们用HEAD时，表示最新的版本。

# ========================================= 
git reset HEAD git_Advanced/testfile.txt
Unstaged changes after reset:
M       git_Advanced/testfile.txt

# ========================================= 
#　接着再丢弃工作区的修改
# ========================================= 
git checkout -- git_Advanced/testfile.txt
# ========================================= 
$ git status
On branch master
nothing to commit, working tree clean
# ========================================= 
# ========================================= 

在Git中，删除也是一个修改操作，我们实战一下，先添加一个新文件test.txt到Git并且提交：


# ========================================= 

$ git add test.txt

$ git commit -m "add test.txt"

# ========================================= 
 rm test.txt
# ========================================= 
git status
On branch master
Your branch is up to date with 'origin/master'.

You are in a sparse checkout with 41% of tracked files present.

Changes not staged for commit:
  (use "git add/rm <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        deleted:    test.txt

no changes added to commit (use "git add" and/or "git commit -a")
# ========================================= 
现在你有两个选择，一是确实要从版本库中删除该文件，那就用命令git rm删掉，并且git commit：

$ git rm test.txt
rm 'test.txt'
# ========================================= 
先手动删除文件，然后使用
git rm <file>和
git add<file>效果是一样的。
# ========================================= 
另一种情况是删错了，因为版本库里还有呢，所以可以很轻松地把误删的文件恢复到最新版本：

# 如果已经在 本目录~/Code/Linux_and_Cluster_for_Omics/git_Advanced :  
# 不需要再加路径
$ git checkout -- test.txt
# ========================================= 
git checkout其实是用版本库里的版本替换工作区的版本，无论工作区是修改还是删除，都可以“一键还原”。

# ========================================= 
# ========================================= 
远程仓库(github) SVN的童鞋，是Git优于VN的杀手级功能之一
# ========================================= 
# ========================================= 


# ========================================= 
在继续阅读后续内容前，请自行注册GitHub账号。
由于你的本地Git仓库和GitHub仓库之间的传输是通过SSH加密的，所以，需要一点设置：

第1步：创建SSH Key。在用户主目录下，看看有没有.ssh目录，如果有，
再看看这个目录下有没有id_rsa和id_rsa.pub这两个文件，
如果已经有了，可直接跳到下一步。如果没有，打开Shell（Windows下打开Git Bash），创建SSH Key：
$ ssh-keygen -t rsa -C "youremail@example.com"
# ========================================= 
为什么GitHub需要SSH Key呢？因为GitHub需要识别出你推送的提交确实是你推送的，而不是别人冒充的，
而Git支持SSH协议，
所以，GitHub只要知道了你的公钥，就可以确认只有你自己才能推送。

当然，GitHub允许你添加多个Key。假定你有若干电脑，你一会儿在公司提交，一会儿在家里提交，
只要把每台电脑的Key都添加到GitHub，就可以在每台电脑上往GitHub推送了。

# ========================================= 

现在，我们根据GitHub的提示，在本地的learngit仓库下运行命令：

$ git remote add origin git@github.com:michaelliao/learngit.git

# ========================================= 
下一步，就可以把本地库的所有内容推送到远程库上：

$ git push -u origin master
# ========================================= 
由于远程库是空的，我们第一次推送master分支时，加上了-u参数，
Git不但会把本地的master分支内容推送的远程新的master分支，
还会把本地的master分支和远程的master分支关联起来，在以后的推送或者拉取时就可以简化命令。
# ========================================= 
从现在起，只要本地作了提交，就可以通过命令：

$ git push origin master
#  zhen 注， git push 即可    <<< =========
# ======================
git remote -v查看远程库信息：
# ========================================= 
分布式版本系统的最大好处之一是在本地工作完全不需要考虑远程库的存在，也就是有没有联网都可以正常工作，
而SVN在没有联网的时候是拒绝干活的！
当有网络的时候，再把本地提交推送一下就完成了同步，真是太方便了！
# ========================================= 
# ========================================= 
如果情况相反，本地库没有
远程库已经准备好了，下一步是用命令git clone克隆一个本地库：

$ git clone git@github.com:michaelliao/gitskills.git

git@github.com:michaelliao/gitskills.git
# ========================================= 

你也许还注意到，GitHub给出的地址不止一个，还可以用

https://github.com/michaelliao/gitskills.git

这样的地址。
实际上，Git支持多种协议，默认的git://使用ssh，但也可以使用https等其他协议。

使用https除了速度慢以外，
还有个最大的麻烦是每次推送都必须输入口令，但是在某些只开放http端口的公司内部
就无法使用ssh协议而只能用https。


# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 
# ========================================= 