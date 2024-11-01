
本仓库参照[文档](https://wiki.gentoo.org/wiki/Project:Overlays/Overlays_guide#Requesting_the_addition_of_an_overlay_via_Github_PRs)  加入了gentoo第三方仓库列表.

[此链接是PR记录](https://github.com/gentoo/api-gentoo-org/pull/641).

从上面[PR文件改动](https://github.com/gentoo/api-gentoo-org/pull/641/files) 可以看出,

gentoo 读取[github上的仓库](https://github.com/guyuming76/suckless_wl_zh), 也就是说如果希望修改对 `emerge --sync suckless_wl_zh` 命令可见,需要把改动commit到 github 仓库.

运行上面 sync 命令会发现, gentoo 实际上是读取[它做的镜像仓库](https://github.com/gentoo-mirror/suckless_wl_zh.git)

# 使用方法 #
使用下面命令获取仓库编号:
```
eselect repository list |grep suckless_wl_zh
```
然后激活并同步:
```
eselect repository enable 上面获取的编号
emerge --sync suckless_wl_zh
```

但我有时发现github从国内访问不稳定,反复尝试很久才能连上同步成功. 这时,不妨尝试手工从gitee上clone到本地:
```
git clone https://gitee.com/guyuming76/suckless_wl_zh.git  /var/db/repos/suckless_wl_zh
```
然后在 /etc/portage/repos.conf/eselect-repo.conf 文件中加入下面内容：
```
[suckless_wl_zh]
location = /var/db/repos/suckless_wl_zh
sync-type = git
sync-uri = https://gitee.com/guyuming76/suckless_wl_zh.git
```
然后 `sudo eix-update`(这一步我不确定是否必要)


在 gentoo 上运行 rfm, 有时会发现 gdk 函数为 .jpg 图片生成thumbnail失败, 需要在 make.conf 里面加上 jpeg USE flag, 然后
```
emerge --ask --verbose --newuse --changed-use --deep @word
```

# 修改ebuild注意事项 #

1. 使用root权限操作

2. 修改完成后执行如下命令,并注意git stage 命令修改的文件.
```
root #pkgdev manifest
root #pkgcheck scan 
```

# ebuild 说明 #
1. 引用的 gui-apps/wtype 包存在于 guru 第三方仓库中, 非gentoo官方仓库.
2. 早期我使用 gui-apps/waybar 配合dwl, 现在已经不用了, 所以对 waybar 依赖的版本一直没更新. 安装时注意 -waybar USE flag就可以了.

## 参考文档 ##

https://wiki.gentoo.org/wiki/Creating_an_ebuild_repository
