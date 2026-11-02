#!/bin/bash

if [ -t 1 ] && [ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]; then
    BOLDGREEN="\e[1;32m"
	BOLDRED="\e[1;31m"
	BOLDCYAN="\e[1;36m"
	BOLDBLUE="\e[1;94m"
	BOLDYELLOW="\e[1;33m"
	ENDCOLOR="\e[0m"
else
    BOLDGREEN=""
	BOLDRED=""
	BOLDCYAN=""
	BOLDBLUE=""
	BOLDYELLOW=""
	ENDCOLOR=""
fi

VERSION=3.1
WIDTH=55

REQUIRED_VALUES=(
	"ARCH"
	"PATHS"
	"CC"
	"CROSS_COMPILE_TOGGLE"
	"SECTION_MISMATCH"
)

declare -A ALLOWED_MAP=(
    ["ARCH"]="arm64 arm x86_64 riscv64"
	["SECTION_MISMATCH"]="y e n"
    ["CROSS_COMPILE_TOGGLE"]="y n"
)

MISSING=0

if [ ! -f config.cfg ]; then
    echo "${BOLDRED}[-] config file not found$ENDCOLOR"
    exit 1
fi

source config.cfg

for var in "${REQUIRED_VALUES[@]}"; do
    val="${!var}"
    
    if [ -z "$val" ]; then
        echo -e "${BOLDRED}[-] '$var' is empty or not set!$ENDCOLOR"
        MISSING=1
        continue
    fi

    val_lower="${val,,}"

    if [ -n "${ALLOWED_MAP[$var]}" ]; then
        allowed_list="${ALLOWED_MAP[$var]}"
        found=0

        for allowed in $allowed_list; do
            if [ "$val_lower" == "$allowed" ]; then
                found=1
                break
            fi
        done

        if [ "$found" -eq 0 ]; then
            echo -e "${BOLDRED}[-] Invalid value '$val' for '$var'! Allowed: $allowed_list$ENDCOLOR"
            MISSING=1
        fi
    fi
done

if [ "$MISSING" -eq 1 ]; then
    echo -e "${BOLDRED}[-] Please fix the configuration errors and try again.$ENDCOLOR"
    exit 1
fi

export PATH="$PATHS:$PATH"
export ARCH=$ARCH
export CC=$CC
[[ -n "$CLANG_TRIPLE" ]] && export CLANG_TRIPLE
if [[ $CROSS_COMPILE_TOGGLE == "y" || $CROSS_COMPILE_TOGGLE == "Y" ]] then
	export CROSS_COMPILE
	if [[ $CROSS_COMPILE_ARM32 ]] then
		export CROSS_COMPILE_ARM32
	fi
fi
[[ -n "$KCFLAGS" ]] && export KCFLAGS
[[ -n "$KCPPFLAGS" ]] && export KCPPFLAGS
[[ -n "$ANDROID_MAJOR_VERSION" ]] && export ANDROID_MAJOR_VERSION
[[ -n "$ENV" ]] && export BUILDER_ENV=$ENV
case $SECTION_MISMATCH in
	y)
		export CONFIG_SECTION_MISMATCH_WARN_ONLY=y
		BUILDER_ENV_2="CONFIG_SECTION_MISMATCH_WARN_ONLY=y"
		;;
	e)
		export CONFIG_SECTION_MISMATCH=y
		export CONFIG_SECTION_MISMATCH_WARN_ONLY=n
		BUILDER_ENV_2="CONFIG_SECTION_MISMATCH=y"
		;;
	n)
		BUILDER_ENV_2=""
		;;
esac
KDIR=$(pwd)
BUILD_OUTPUT="$KDIR/build/output"

function formatLine() {
    local text="$1"
    
    local visible_text
    visible_text=$(echo -e "$text" | sed 's/\x1B\[[0-9;]*[mK]//g')
    local visible_len=${#visible_text}
    
    local padding=$(( WIDTH - visible_len ))
    if [ $padding -lt 0 ]; then
        padding=0
    fi
    
    printf "│%s%*s│\n" "$text" "$padding" ""
}

function show_gui() {
	CCVersion=$($CC --version | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
	if [ -f "$KDIR/$OUT_DIR/.config" ]; then
		CONFIG_STATUS="${BOLDGREEN}Config present$ENDCOLOR"
	else
		CONFIG_STATUS="${BOLDRED}No .config found$ENDCOLOR"
	fi
	DASHES=$(printf '─%.0s' $(seq 1 "$WIDTH"))
	BORDER_TOP="┌${DASHES}┐"
	BORDER_MID="├${DASHES}┤"
	BORDER_BOTTOM="└${DASHES}┘"

	clear
	echo -e "$BOLDBLUE"
	echo -e "\t$BORDER_TOP"
    echo -e "\t$(formatLine "   ██╗  ██╗███████╗██████╗ ███╗   ██╗███████╗██╗       ")"
    echo -e "\t$(formatLine "   ██║ ██╔╝██╔════╝██╔══██╗████╗  ██║██╔════╝██║       ")"
    echo -e "\t$(formatLine "   █████╔╝ █████╗  ██████╔╝██╔██╗ ██║█████╗  ██║       ")"
    echo -e "\t$(formatLine "   ██╔═██╗ ██╔══╝  ██╔══██╗██║╚██╗██║██╔══╝  ██║       ")"
    echo -e "\t$(formatLine "   ██║  ██╗███████╗██║  ██║██║ ╚████║███████╗███████╗  ")"
    echo -e "\t$(formatLine "   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚═╝  ╚═══╝╚══════╝╚══════╝  ")"
    echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "          B U I L D E R   V $VERSION")$ENDCOLOR"
    echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "                     $ENDCOLOR STATUS$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}By: ${BOLDYELLOW}Karam (karamdev1)$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}Version: ${BOLDYELLOW}v$VERSION$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine)$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}ARCH: $BOLDYELLOW${ARCH}$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}CC Version: ${BOLDYELLOW}$CCVersion$BOLDBLUE")$ENDCOLOR"
	if [[ $CLANG_TRIPLE ]] then
		echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}CLANG_TRIPLE: ${BOLDYELLOW}$(basename $CLANG_TRIPLE)$BOLDBLUE")$ENDCOLOR"
	fi
	if [[ $CROSS_COMPILE_TOGGLE == "y" || $CROSS_COMPILE_TOGGLE == "Y" ]] then
		echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}CROSS_COMPILE: ${BOLDYELLOW}$(basename $CROSS_COMPILE)$BOLDBLUE")$ENDCOLOR"
		if [[ $CROSS_COMPILE_ARM32 ]] then
			echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}CROSS_COMPILE_ARM32: ${BOLDYELLOW}$(basename $CROSS_COMPILE_ARM32)$BOLDBLUE")$ENDCOLOR"
		fi
	fi
	echo -e "\t$BOLDBLUE$(formatLine "${BOLDCYAN}Kernel Config: ${CONFIG_STATUS}$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine)$ENDCOLOR"
	echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "                     $ENDCOLOR KERNEL$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}1$ENDCOLOR] Compile Kernel from scratch$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}2$ENDCOLOR] Compile Kernel from last run$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}3$ENDCOLOR] Compile Module     $BOLDCYAN(Auto prepares!)$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}4$ENDCOLOR] Prepare Module$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}5$ENDCOLOR] Copy Modules       $BOLDCYAN(Compile First!)$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}6$ENDCOLOR] Apply Defconfig$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}7$ENDCOLOR] Edit Config$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}8$ENDCOLOR] Save config as new defconfig$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}0$ENDCOLOR] Clean Environment$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine)$ENDCOLOR"
	echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "                     $ENDCOLOR OTHER$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$BORDER_MID$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDRED}E$ENDCOLOR] Exit Builder$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$(formatLine "$ENDCOLOR[${BOLDCYAN}G$ENDCOLOR] Open the creator's github page$BOLDBLUE")$ENDCOLOR"
	echo -e "\t$BOLDBLUE$BORDER_BOTTOM$ENDCOLOR"
	echo
}

function archiveBuild() {
	local buildTime=$(date +"%Y-%m-%d_%H-%M-%S")
	if [[ -d "$KDIR/$OUT_DIR/arch/$ARCH/boot" ]] then
		mapfile -t images < <(find "$KDIR/$OUT_DIR/arch/$ARCH/boot" -type f)

		if [ ${#images[@]} -eq 0 ]; then
			echo -e "$BOLDRED[-] No images found!$ENDCOLOR"
			return
		fi

		if [[ ! -d "$BUILD_OUTPUT" ]] then
			mkdir -p "$BUILD_OUTPUT"
		fi
		mkdir -p "$BUILD_OUTPUT/$buildTime"
		
		cp $KDIR/$OUT_DIR/arch/$ARCH/boot/Image* "$BUILD_OUTPUT/$buildTime/"
		path=$(echo "$BUILD_OUTPUT/$buildTime" | awk -F'/' '{OFS="/"; print $(NF-3), $(NF-2), $(NF-1), $NF}')
		echo -e "$BOLDGREEN[+] You can find the compiled Images in '$path'!$ENDCOLOR"
	fi
}

function compileKernel() {
	echo -e "$BOLDGREEN[+] Building$ENDCOLOR"
	if [ ! -f "$KDIR/$OUT_DIR/.config" ]; then
		echo -e "$BOLDRED[-] There is no applied config!$ENDCOLOR"
	else
		make -s -C "$KDIR" O="$OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 -j"$(nproc)"
		ret=$?
		if [ $ret -eq 0 ]; then
			echo -e "$BOLDGREEN[+] Kernel Building Succeed!$ENDCOLOR"
			archiveBuild
		else
			echo -e "$BOLDRED[-] Kernel Building Failed (exit code: $ret)!$ENDCOLOR"
		fi
	fi
}

function compileModules() {
	echo -e "$BOLDGREEN[+] Building Modules$ENDCOLOR"
	if [ ! -f "$KDIR/$OUT_DIR/.config" ]; then
		echo -e "$BOLDRED[-] There is no applied config!$ENDCOLOR"
	else
		make -s -C "$KDIR" O="$OUT_DIR" INSTALL_MOD_PATH="$MODULES_OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 modules -j"$(nproc)"
		ret=$?
		if [ $ret -eq 0 ]; then
			echo -e "$BOLDGREEN[+] Modules Building Succeed$ENDCOLOR"
			echo -e "$BOLDGREEN[+] You can find the modules in $MODULES_OUT_DIR$ENDCOLOR"
		else
			echo -e "$BOLDRED[-] Modules Building Failed (exit code: $ret)$ENDCOLOR"
		fi
	fi
}

function prepareModules() {
	echo -e "$BOLDGREEN[+] Preparing Modules$ENDCOLOR"
	if [ ! -f "$KDIR/$OUT_DIR/.config" ]; then
		echo -e "$BOLDRED[-] There is no applied config!$ENDCOLOR"
	else
		make -s -C "$KDIR" O="$OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 modules_prepare -j"$(nproc)"
		ret=$?
		if [ $ret -eq 0 ]; then
			echo -e "$BOLDGREEN[+] Preparing Modules Succeed$ENDCOLOR"
		else
			echo -e "$BOLDRED[-] Preparing Modules Failed (exit code: $ret)$ENDCOLOR"
		fi
	fi
}

function copyModules() {
	echo -e "$BOLDGREEN[+] Coping Modules to $MODULES_OUT_DIR$ENDCOLOR"
	if [ ! -f "$KDIR/$OUT_DIR/.config" ]; then
		echo -e "$BOLDRED[-] There is no applied config!$ENDCOLOR"
	else
		make -C "$KDIR" O="$OUT_DIR" INSTALL_MOD_PATH="$MODULES_OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 modules_install -j"$(nproc)"
		ret=$?
		if [ $ret -eq 0 ]; then
			echo -e "$BOLDGREEN[+] Coping Building Succeed$ENDCOLOR"
			echo -e "$BOLDGREEN[+] You can find the modules in $MODULES_OUT_DIR$ENDCOLOR"
		else
			echo -e "$BOLDRED[-] Coping Building Failed (exit code: $ret)$ENDCOLOR"
		fi
	fi
}

function cleanKernel() {
	echo -e "$BOLDGREEN[+] Cleaning$ENDCOLOR"
	local folders=(
		$MODULES_OUT_DIR
	)
	local deleted=0
	echo -e "$BOLDGREEN  [+] Deleting Folders"
	for folder in "${folders[@]}"; do
		if [[ -d "$KDIR/$folder" ]] then
			rm -rf $folder
			ret=$?
			if [ $ret -eq 0 ]; then
				echo -e "$BOLDGREEN    [+] Deleting '$folder' folder Succeed!$ENDCOLOR"
				deleted=1
			else
				echo -e "$BOLDRED    [-] Deleting Failed (exit code: $ret)$ENDCOLOR"
			fi
		fi
	done
	if [[ "$deleted" -eq 1 ]] then
		echo -e "$BOLDGREEN  [+] Deleting Folders Finished$ENDCOLOR"
	else
		echo -e "$BOLDRED  [-] No folders were deleted$ENDCOLOR"
	fi
	if [[ -d "$OUT_DIR" ]] then
		echo -e "$BOLDGREEN[+] Cleaning '$OUT_DIR'!$ENDCOLOR"
		make -s -C "$KDIR" O="$OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 clean -j"$(nproc)" && make -s -C "$KDIR" O="$OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 mrproper -j"$(nproc)"
		ret=$?
		if [ $ret -eq 0 ]; then
			echo -e "$BOLDGREEN[+] Cleaning '$OUT_DIR' Succeed!$ENDCOLOR"
		else
			echo -e "$BOLDRED[-] Cleaning '$OUT_DIR' Failed (exit code: $ret)$ENDCOLOR"
		fi
	fi
	echo -e "$BOLDGREEN[+] Cleaning kernel!$ENDCOLOR"
	make -s -C "$KDIR" $BUILDER_ENV $BUILDER_ENV_2 clean -j"$(nproc)" && make -s -C "$KDIR" $BUILDER_ENV $BUILDER_ENV_2 mrproper -j"$(nproc)"
	ret=$?
	if [ $ret -eq 0 ]; then
		echo -e "$BOLDGREEN[+] Cleaning kernel Succeed!$ENDCOLOR"
	else
		echo -e "$BOLDRED[-] Cleaning kernel Failed (exit code: $ret)$ENDCOLOR"
	fi
}

function applyDefconfig() {
	local config=$1
	if [[ ! -d "$KDIR/arch/$ARCH/configs" ]] then
		echo -e "$BOLDRED[-] Config dir for the arch '$ARCH' is not found!$ENDCOLOR"
	else
		mapfile -t files < <(find "arch/$ARCH/configs/" -type f | sed 's|^[^/]*/[^/]*/[^/]*/||' | sort)

		if [ ${#files[@]} -eq 0 ]; then
			echo -e "$BOLDRED[-] No configs found!$ENDCOLOR"
			exit 1
		fi

		local SELECTED_FILE=""
		
		if [[ ! $config ]] then
			echo -e "$BOLDGREEN[+] Please choose a file by entering its number: $ENDCOLOR"

			for i in "${!files[@]}"; do
				printf "  [${BOLDCYAN}%d$ENDCOLOR] $BOLDYELLOW%s$ENDCOLOR\n" "$((i + 1))" "${files[i]}"
			done

			echo -ne "${BOLDCYAN}Enter selection number: $ENDCOLOR"
			read choice

			local index=$((choice - 1))
			if [ "$index" -ge 0 ] && [ "$index" -lt "${#files[@]}" ]; then
				SELECTED_FILE="${files[index]}"
				echo -e "$BOLDCYAN[!] You selected: ${BOLDYELLOW}$SELECTED_FILE$ENDCOLOR"
			else
				echo -e "$BOLDRED[-] Invalid selection.$ENDCOLOR"
				return
			fi
		else
			if [[ ! -f "$KDIR/arch/$ARCH/configs/$config" ]] then
				echo -e "$BOLDRED[-] Config '$config' not found!$ENDCOLOR"
				return
			fi
			SELECTED_FILE=$config
			echo -e "$BOLDCYAN[!] File selected: ${BOLDYELLOW}$SELECTED_FILE$ENDCOLOR"
		fi

		make -C "$KDIR" O="$OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 $SELECTED_FILE -j"$(nproc)"
		ret=$?
		if [ $ret -eq 0 ]; then
			echo -e "$BOLDGREEN[+] Config Applying Succeed!$ENDCOLOR"
		else
			echo -e "$BOLDRED[-] Config Applying Failed (exit code: $ret)$ENDCOLOR"
		fi
	fi	
}

function editConfig() {
	echo -e "$BOLDGREEN[+] Editing Config$ENDCOLOR"
	make -C "$KDIR" O="$OUT_DIR" $BUILDER_ENV $BUILDER_ENV_2 nconfig -j"$(nproc)"
}

function saveConfig() {
	echo -e "$BOLDGREEN[+] Saving current config as new defconfig$ENDCOLOR"
	if [ ! -f "$KDIR/$OUT_DIR/.config" ]; then
		echo -e "$BOLDRED[!] config is not found$ENDCOLOR"
	else
		echo -ne "$BOLDGREEN[!] Enter the new defconfig name: $ENDCOLOR"
		read newconfig
		if [ -f "$KDIR/arch/$ARCH/configs/$newconfig" ]; then
			echo -e "$BOLDRED[!] $newconfig is found"
			echo -ne "Do you want to overwrite it?$ENDCOLOR [y,N]: "
			read answer
			case "$answer" in
				Y|y)
					echo -e "$BOLDGREEN[+] Overwriting current .config as $newconfig$ENDCOLOR"
					cp "$KDIR/$OUT_DIR/.config" "$KDIR/arch/$ARCH/configs/$newconfig"
					ret=$?
					if [ $ret -eq 0 ]; then
						echo -e "$BOLDGREEN[+] Coping succeed!$ENDCOLOR"
					else
						echo -e "$BOLDRED[-] Coping Failed (exit code: $ret)$ENDCOLOR"
					fi
					;;
				N|n|'')
					echo -e "$BOLDGREEN[!] Skipped Saving the new defconfig!$ENDCOLOR"
					;;
			esac
		else
			echo -e "$BOLDGREEN[+] Saving current .config as $newconfig$ENDCOLOR"
			cp "$KDIR/$OUT_DIR/.config" "$KDIR/arch/$ARCH/configs/$newconfig"
			ret=$?
			if [ $ret -eq 0 ]; then
				echo -e "$BOLDGREEN[+] Coping succeed!$ENDCOLOR"
			else
				echo -e "$BOLDRED[-] Coping Failed (exit code: $ret)$ENDCOLOR"
			fi
		fi
	fi
}

function interactive() {
    while true; do
		show_gui
		echo -ne "${BOLDCYAN}Enter the action [0-8/E/G]: $ENDCOLOR"
		read action

		case $action in
			1)
				cleanKernel && applyDefconfig && compileKernel
				;;
			2)
				compileKernel
				;;
			3)
				prepareModules && compileModules
				;;
			4)
				prepareModules
				;;
			5)
				copyModules
				;;
			6)
				applyDefconfig
				;;
			7)
				editConfig
				;;
			8)
				saveConfig
				;;
			0)
				cleanKernel
				;;
			E|e)
				echo -e "$BOLDRED[!] Exiting!!$ENDCOLOR"
				break
				;;
			G|g)
				echo -e "$BOLDGREEN[+] Opening the creator's github page$ENDCOLOR"
				xdg-open https://github.com/karamdev1 > /dev/null 2>&1 &
				;;
			*)
				echo -e "$BOLDRED[!] Invalid Action!!$ENDCOLOR"
				;;
		esac
		echo -ne "${BOLDYELLOW}Press enter to continue$ENDCOLOR"
		read
	done
}

function showHelp() {
    echo -e "${BOLDBLUE}Kernel Builder v$VERSION"
    echo
    echo -e "${BOLDCYAN}Usage: ${BOLDGREEN}./build.sh ${BOLDYELLOW}[command]"
    echo
    echo -e "${BOLDCYAN}Commands:"
    echo -e "$BOLDBLUE  build               $BOLDYELLOW Compile kernel"
    echo -e "$BOLDBLUE  modules             $BOLDYELLOW Prepare and compile modules"
    echo -e "$BOLDBLUE  prepare             $BOLDYELLOW Prepare modules"
	echo -e "$BOLDBLUE  copyModules         $BOLDYELLOW Copy modules"
	echo -e "$BOLDBLUE  applyConfig $BOLDRED[file]  $BOLDYELLOW Apply a defconfig file"
    echo -e "$BOLDBLUE  clean               $BOLDYELLOW Clean build environment"
    echo -e "$BOLDBLUE  help                $BOLDYELLOW Show this help"
    echo
    echo -e "${BOLDYELLOW}No command starts the interactive menu.$ENDCOLOR"
}

case "${1:-interactive}" in
    build)
        compileKernel
        exit $?
        ;;
    modules)
        prepareModules && compileModules
        exit $?
        ;;
    prepare)
        prepareModules
        exit $?
        ;;
	copyModules)
		copyModules
		exit $?
        ;;
	applyConfig)
		if [[ ! $2 ]] then
			echo -e "${BOLDRED}[-] Enter the defconfig's filename!$ENDCOLOR"
			exit 1
		fi
		applyDefconfig $2
        exit $?
        ;;
    clean)
        cleanKernel
        exit $?
        ;;
    help|--help|-h)
        showHelp
        exit 0
        ;;
    interactive)
        interactive
        ;;
    *)
        echo -e "${BOLDRED}Unknown command: $BOLDYELLOW$1$ENDCOLOR"
        showHelp
        exit 2
        ;;
esac