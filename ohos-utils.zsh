# utils for hos development

#==========================================================================
find-repo-root () {
    currentPath=$(pwd)
    while [[ "$currentPath" != "" && ! -e "$currentPath/.repo" ]]; do
        currentPath=${currentPath%/*}
    done
    echo "$currentPath"
}

function gen-build-path-env()
{
    # magic path extracted from build_scripts/build.sh
    echo "${OHOS_BUILD_TOP}/prebuilts/python/linux-x86/3.8.5/bin:${OHOS_BUILD_TOP}/prebuilts/build-tools/linux-x86/bin"
}

#==========================================================================

#prepare build environment
function ohos-conf()
{
    local GUESS_OHOS_BUILD_TOP=$(find-repo-root)
    if [[ -z $GUESS_OHOS_BUILD_TOP ]]; then
        echo 'error finding repo root'
        return -1
    fi

    if [[ $OHOS_BUILD_TOP != $GUESS_OHOS_BUILD_TOP ]] || [ ! -d $OHOS_PRODUCT_OUT ]; then
        export OHOS_BUILD_TOP=$GUESS_OHOS_BUILD_TOP
        export OHOS_PRODUCT_OUT=$GUESS_OHOS_BUILD_TOP/out/$(ls out -t |grep -P '^(?!preloader|kernel|sdk)'|head -n 1)
    fi

    if ! command -v hdc_std &> /dev/null; then
        if [ -f $OHOS_BUILD_TOP/out/sdk/ohos-sdk/linux/toolchains/hdc_std ]; then
            export PATH=$OHOS_BUILD_TOP/out/sdk/ohos-sdk/linux/toolchains/:$PATH
        else
            echo "hdc_std not found"
        fi
    fi

    return 0
}

#==========================================================================

function ohos-croot()
{
    ohos-conf
    cd $OHOS_BUILD_TOP
}

# manaully regenerate build.ninja
function ohos-gn()
{
    ohos-conf
    PATH=$(gen-build-path-env):$PATH gn --root=${OHOS_BUILD_TOP} -q gen ${OHOS_PRODUCT_OUT}/
}

# build
function ohos-make()
{
    ohos-conf
    if [ ! -f ${OHOS_PRODUCT_OUT}/build.ninja ]; then
        echo "build.ninja not found, run ohos-gn first"
    fi

    # disable gn update
    sed -i \
        -e 's/generator = 1/generator = 0/' \
        ${OHOS_PRODUCT_OUT}/build.ninja

    # build with ccache and pycache
    PATH=$(gen-build-path-env):$PATH USE_CCACHE="1" CCACHE_DIR="$HOME/CC_TMP" PYCACHE_DIR="$HOME/.pycache" PYCACHE_ENABLE="true" \
        ninja -d keepdepfile -d keeprsp -w dupbuild=err -C $OHOS_PRODUCT_OUT $@
}

function ohos-exec-docker()
{
    docker run --rm -it -v $HOME:$HOME --workdir="$(pwd)" ooxx/hos-dev:0.0.1 $@
}

function ohos-push()
{
    # todo
    echo "===== done ====="
}

function ohos-apply()
{
    ohos-make "$@" && \
    ohos-push "$@"
}

#==========================================================================

function generate-clean-compiledb()
{
    ohos-conf
    ninja -C $OHOS_PRODUCT_OUT -t compdb | \
        jq --unbuffered 'del(.[] | select(.output|test("(_mingw|_android|_multi|_mac|_windows|Test\/)"))) | del(.[] | select(.output|test("(\\.o)$")|not))' | \
        > $OHOS_BUILD_TOP/compile_commands.json
}
