param(
    [string]$VcVarsPath = 'C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $VcVarsPath)) { throw "MSVC environment not found: $VcVarsPath" }
$coreRoot = $PSScriptRoot
$buildRoot = Join-Path $coreRoot 'build\windows-msvc'
New-Item -ItemType Directory -Force -Path $buildRoot | Out-Null
$sources = @(
    'libretro.c', 'intv.c', 'memory.c', 'cp1610.c', 'cart.c',
    'controller.c', 'remote_input.c', 'osd.c', 'ivoice.c', 'psg.c',
    'stic.c', 'stb_image_impl.c',
    'deps/libretro-common/file/file_path.c',
    'deps/libretro-common/file/file_path_io.c',
    'deps/libretro-common/compat/compat_posix_string.c',
    'deps/libretro-common/compat/compat_snprintf.c',
    'deps/libretro-common/compat/compat_strl.c',
    'deps/libretro-common/compat/compat_strcasestr.c',
    'deps/libretro-common/compat/fopen_utf8.c',
    'deps/libretro-common/encodings/encoding_utf.c',
    'deps/libretro-common/string/stdstring.c',
    'deps/libretro-common/streams/file_stream.c',
    'deps/libretro-common/time/rtime.c',
    'deps/libretro-common/vfs/vfs_implementation.c'
)
$exports = @(
    'retro_api_version', 'retro_cheat_reset', 'retro_cheat_set', 'retro_deinit',
    'retro_get_memory_data', 'retro_get_memory_size', 'retro_get_region',
    'retro_get_system_av_info', 'retro_get_system_info', 'retro_init',
    'retro_load_game', 'retro_load_game_special', 'retro_reset', 'retro_run',
    'retro_serialize', 'retro_serialize_size', 'retro_set_audio_sample',
    'retro_set_audio_sample_batch', 'retro_set_controller_port_device',
    'retro_set_environment', 'retro_set_input_poll', 'retro_set_input_state',
    'retro_set_video_refresh', 'retro_unload_game', 'retro_unserialize'
)
$defPath = Join-Path $buildRoot 'freeintv_controller_libretro.def'
@('LIBRARY freeintv_controller_libretro', 'EXPORTS') + $exports |
    Set-Content -LiteralPath $defPath -Encoding ASCII
$commands = @('@echo off', "call `"$VcVarsPath`"", 'if errorlevel 1 exit /b 1')
$objects = @()
foreach ($source in $sources) {
    $sourcePath = Join-Path $coreRoot "src\$source"
    $objectPath = Join-Path $buildRoot ([IO.Path]::GetFileNameWithoutExtension($source) + '.obj')
    $objects += "`"$objectPath`""
    $commands += "cl /nologo /c /O2 /MT /utf-8 /D_CRT_SECURE_NO_WARNINGS /D_CRT_NONSTDC_NO_DEPRECATE /I`"$coreRoot\src`" /I`"$coreRoot\src\deps\libretro-common\include`" /Fo`"$objectPath`" `"$sourcePath`""
    $commands += 'if errorlevel 1 exit /b 1'
}
$dllPath = Join-Path $buildRoot 'freeintv_controller_libretro.dll'
$commands += "link /nologo /DLL /OUT:`"$dllPath`" /DEF:`"$defPath`" $($objects -join ' ') ws2_32.lib bcrypt.lib user32.lib shell32.lib advapi32.lib"
$commands += 'if errorlevel 1 exit /b 1'
$cmdPath = Join-Path $buildRoot 'build-core.cmd'
$commands | Set-Content -LiteralPath $cmdPath -Encoding ASCII
& $env:ComSpec /d /c $cmdPath
if ($LASTEXITCODE -ne 0) { throw "Core build failed with exit code $LASTEXITCODE" }
Copy-Item -LiteralPath (Join-Path $coreRoot 'FreeIntv_libretro.info') -Destination (Join-Path $buildRoot 'freeintv_controller_libretro.info') -Force
Get-Item -LiteralPath $dllPath | Select-Object FullName, Length, LastWriteTime
