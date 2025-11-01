param (
    [string]$VERSION
)

Set-Location E:\ZEngine\engine\3rdparty
Write-Output "=====[ Getting Depot Tools ]====="
# Invoke-WebRequest -Uri "https://storage.googleapis.com/chrome-infra/depot_tools.zip" -OutFile "depot_tools.zip"
# 7z x depot_tools.zip -o*
$env:PATH = "$PWD\depot_tools;$env:PATH"
$env:GYP_MSVS_VERSION = "2019"
$env:DEPOT_TOOLS_WIN_TOOLCHAIN = "0"
# & gclient

# if ($VERSION -ne "10.6.194" -and $VERSION -ne "11.8.172") {
#     Set-Location depot_tools
#     & git reset --hard 8d16d4a
#     Set-Location ..
# }
$env:DEPOT_TOOLS_UPDATE = "0"

# mkdir v8
Set-Location v8

Write-Output "=====[ Fetching V8 ]====="
# & fetch v8
# cd v8
# & git checkout "refs/tags/$VERSION"
# cd test\test262\data
# & git config --system core.longpaths true
# & git restore *
# cd ..\..\..\
# & gclient sync

if ($VERSION -eq "10.6.194") {
    Write-Output "=====[ patch 10.6.194 ]====="
    node "$PSScriptRoot\node-script\do-gitpatch.js" -p "$env:GITHUB_WORKSPACE\patches\win_msvc_v10.6.194.patch"
}

if ($VERSION -eq "11.8.172") {
    Write-Host "=====[ patch 11.8.172 ]====="
    node "$PSScriptRoot\node-script\do-gitpatch.js" -p "$env:GITHUB_WORKSPACE\patches\remove_uchar_include_v11.8.172.patch"
    node "$PSScriptRoot\node-script\do-gitpatch.js" -p "$env:GITHUB_WORKSPACE\patches\win_dll_v11.8.172.patch"
}

# if ($VERSION -eq "9.4.146.24") {
#     Write-Output "=====[ patch jinja for python3.10+ ]====="
#     Set-Location third_party\jinja2
#     node "$PSScriptRoot\node-script\do-gitpatch.js" -p "$env:GITHUB_WORKSPACE\patches\jinja_v9.4.146.24.patch"
#     Set-Location ..\..
# }

# Write-Output "=====[ Patching V8 ]====="
# node "$env:GITHUB_WORKSPACE\CRLF2LF.js" "$env:GITHUB_WORKSPACE\patches\builtins-puerts.patches"
# & git apply --cached --reject "$env:GITHUB_WORKSPACE\patches\builtins-puerts.patches"
# & git checkout -- .

Write-Output "=====[ Make dynamic_crt ]====="
# node "$PSScriptRoot\node-script\rep.js" "build\config\win\BUILD.gn"

Write-Output "=====[ add ArrayBuffer_New_Without_Stl ]====="
# node "$PSScriptRoot\node-script\add_arraybuffer_new_without_stl.js" "." "$VERSION"

# node "$PSScriptRoot\node-script\patchs.js" "." "$VERSION"

Write-Output "=====[ Building V8 ]====="
if ($VERSION -eq "10.6.194" -or $VERSION -eq "11.8.172") {
    $v8_args = 'target_os=\"win\" target_cpu=\"x64\" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=false v8_static_library=true is_clang=false strip_debug_info=true symbol_level=0 v8_enable_pointer_compression=false v8_enable_sandbox=false'
} else {
    # 添加 extra_cppflags 来禁用 C4834 警告
    $v8_args = 'target_os=\"win\" target_cpu=\"x64\" v8_use_external_startup_data=false v8_enable_i18n_support=false is_debug=true v8_static_library=true is_clang=false strip_debug_info=true symbol_level=0 v8_enable_pointer_compression=false treat_warnings_as_errors=false'
}
# Generate build files
Write-Output "Generating build configuration..."
$gnResult = & gn gen out.gn\x64.debug "--args=$v8_args" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "GN generation failed!"
    Write-Output $gnResult
    exit $LASTEXITCODE
}

# Clean build directory
Write-Output "Cleaning build directory..."
& ninja -C "out.gn\x64.debug" -t clean 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Warning "Clean failed, continuing..."
}

# Build with detailed output and logging
Write-Output "Starting build..."
$buildLog = "out.gn\x64.debug\ninja_build.log"
$buildResult = & ninja -v -C "out.gn\x64.debug" wee8 2>&1 | Tee-Object -FilePath $buildLog

# Also capture errors separately
if ($LASTEXITCODE -ne 0) {
    Write-Error "========================================="
    Write-Error "BUILD FAILED with exit code: $LASTEXITCODE"
    Write-Error "========================================="
    Write-Output ""
    Write-Output "Detailed error output:"
    Write-Output $buildResult
    Write-Output ""
    Write-Error "Full build log saved to: $PWD\$buildLog"
    Write-Error "To see more details, check the log file or run:"
    Write-Error "  ninja -v -C `"out.gn\x64.debug`" wee8"
    Write-Error ""
    Write-Error "To get even more verbose output, you can use:"
    Write-Error "  ninja -v2 -C `"out.gn\x64.debug`" wee8"
    Write-Error "  or"
    Write-Error "  ninja -v3 -C `"out.gn\x64.debug`" wee8"
    Write-Error ""
    Write-Error "To see the failed command details:"
    Write-Error "  cd `"out.gn\x64.debug`""
    Write-Error "  ninja -t explain"
    exit $LASTEXITCODE
}

mkdir -Force output\v8\Lib\Win64MD_Debug
Copy-Item -Force "out.gn\x64.debug\obj\wee8.lib" "output\v8\Lib\Win64MD_Debug\"
mkdir -Force output\v8\Inc\Blob\Win64MD_Debug
