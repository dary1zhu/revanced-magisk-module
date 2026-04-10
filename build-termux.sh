#!/usr/bin/env bash

set -e

# 颜色输出函数
pr() { echo -e "\033[0;32m[+] ${1}\033[0m"; }

# 环境初始化 (每月检查一次)
if [ ! -f ~/.morphe_env_"$(date '+%Y%m')" ]; then
	pr "正在初始化构建环境 (Java 17, Git, JQ...)"
	pkg update -y && pkg upgrade -y
	pkg install -y git curl jq openjdk-17 zip termux-api
	: >~/.morphe_env_"$(date '+%Y%m')"
fi

pr "获取存储权限..."
termux-setup-storage
sleep 1
# 创建下载目录
DOWNLOAD_DIR="/sdcard/Download/revanced-custom-build"
mkdir -p "$DOWNLOAD_DIR"

# --- 核心修改：仓库地址 ---
# 请将下面的 URL 换成你自己修改后的那个仓库地址
REPO_URL="https://github.com/dary1zhu/revanced-magisk-module"
LOCAL_DIR="revanced-magisk-module"

if [ -d "$LOCAL_DIR" ] || [ -f config.toml ]; then
	if [ -d "$LOCAL_DIR" ]; then cd "$LOCAL_DIR"; fi
	pr "检查构建脚本更新..."
	git fetch
	if git status | grep -q 'is behind\|fatal'; then
		pr "本地脚本与远程不同步，正在重新拉取..."
		cd ..
		[ -f "$LOCAL_DIR/config.toml" ] && cp -f "$LOCAL_DIR/config.toml" .
		rm -rf "$LOCAL_DIR"
		git clone "$REPO_URL" --recurse --depth 1 "$LOCAL_DIR"
		[ -f config.toml ] && mv -f config.toml "$LOCAL_DIR/config.toml"
		cd "$LOCAL_DIR"
	fi
else
	pr "正在克隆构建仓库..."
	git clone "$REPO_URL" --depth 1 "$LOCAL_DIR"
	cd "$LOCAL_DIR"
	# 默认禁用所有应用，由用户手动开启
	sed -i '/^enabled.*/d; /^\[.*\]/a enabled = false' config.toml
	grep -q "$LOCAL_DIR" ~/.gitconfig 2>/dev/null ||
		git config --global --add safe.directory ~/"$LOCAL_DIR"
fi

# 备份配置文件到下载目录方便编辑
[ -f ~/storage/downloads/morphe-magisk-module/config.toml ] ||
	cp config.toml ~/storage/downloads/morphe-magisk-module/config.toml

# 注意：j-hc 的网页生成器是针对 ReVanced 的，Piko 的补丁名可能不同
if ask "是否打开浏览器参考配置生成器？(注意：补丁名可能与网页不同)"; then
	am start -a android.intent.action.VIEW -d https://j-hc.github.io/rvmm-config-gen/
fi

printf "\n"
until
	if ask "是否现在编辑 'config.toml'？\n(你需要将想构建的应用 enabled 改为 true)"; then
		# 调用系统编辑器打开下载目录下的配置文件
		am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphe-magisk-module/config.toml -t text/plain
	fi
	ask "配置完成，是否开始构建模块？"
do :; done

# 同步编辑后的配置并开始构建
cp -f ~/storage/downloads/morphe-magisk-module/config.toml config.toml
./build.sh

# 移动产物到下载文件夹
cd build
PWD=$(pwd)
for op in *; do
	[ "$op" = "*" ] && {
		pr "未发现生成的文件，可能构建失败了。"
		exit 1
	}
	mv -f "${PWD}/${op}" ~/storage/downloads/morphe-magisk-module/"${op}"
done

pr "构建完成！文件保存在：内部存储/Download/morphe-magisk-module"
# 自动打开文件夹
am start -a android.intent.action.VIEW -d file:///sdcard/Download/morphe-magisk-module -t resource/folder
