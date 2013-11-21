@rem Copyright (c) 2013 Google, Inc.
@rem
@rem This software is provided 'as-is', without any express or implied
@rem warranty.  In no event will the authors be held liable for any damages
@rem arising from the use of this software.
@rem Permission is granted to anyone to use this software for any purpose,
@rem including commercial applications, and to alter it and redistribute it
@rem freely, subject to the following restrictions:
@rem 1. The origin of this software must not be misrepresented; you must not
@rem claim that you wrote the original software. If you use this software
@rem in a product, an acknowledgment in the product documentation would be
@rem appreciated but is not required.
@rem 2. Altered source versions must be plainly marked as such, and must not be
@rem misrepresented as being the original software.
@rem 3. This notice may not be removed or altered from any source distribution.
@echo off
rem See help text below or run with -h for a description of this batch file.

rem Project name.
set project_name=Splash2D
rem Minimum cmake version this project has been tested with.
set cmake_minversion_minmaj=2.8
rem Build configuration options.
set solution_to_build=Box2D.sln
rem Default set of configurations to build.
set build_configuration_default=Debug MinSizeRel Release RelWithDebInfo
rem Default arguments for msbuild.exe.
set msbuild_args=/m:%NUMBER_OF_PROCESSORS% /t:Rebuild
rem Newest and oldest version of Visual Studio that it's possible to select.
set visual_studio_version_max=12
set visual_studio_version_min=8

rem Help text.
if "%1"=="-h" (
  echo Generate Visual Studio Solution for %project_name% and build the
  echo specified set of configurations.
  echo.
  echo Usage: %~nx0 [build_configurations] [visual_studio_version]
  echo.
  echo build_configurations: Is space separated list of build configurations
  echo that should be built by this script.  If this isn't specified it
  echo defaults to all build configurations generated by CMake
  echo "Debug MinSizeRel Release RelWithDebInfo".
  echo.
  echo visual_studio_version: Version of Visual Studio cmake generator to use.
  echo If this isn't specified the newest version of Visual Studio installed
  echo will be selected.
  echo.
  echo For example to just build the Debug configuration:
  echo   %~nx0 Debug
  echo.
  exit /B -1
)

rem Set the build configuration or fallback to the default set.
set build_configuration=%1
if "%build_configuration%" == "" (
  set build_configuration=%build_configuration_default%
)
set visual_studio_version=%2
if "%visual_studio_version%"=="" (
  set visual_studio_version=%visual_studio_version_max%
)

rem Change into this batch file's directory.
cd %~d0%~p0

rem Search the path for cmake.
set cmake=
rem Look for a prebuilt cmake in the tree.
set android_root=..\..\..\..\..\..\
for %%a in (%android_root%) do (
  set android_root=%%~da%%~pa
)
set cmake_prebuilts_root=%android_root%prebuilts\cmake\windows
for /F %%a in ('dir /b %cmake_prebuilts_root%\cmake-*') do (
  if exist %cmake_prebuilts_root%\%%a\bin\cmake.exe (
    set cmake_prebuilt=%cmake_prebuilts_root%\%%a\bin\cmake.exe
    goto found_cmake_prebuilt
  )
)
:found_cmake_prebuilt

if exist %cmake_prebuilt% (
  set cmake=%cmake_prebuilt%
  goto check_cmake_version
)
echo Searching PATH for cmake. >&2
for /F "delims=;" %%a in ('where cmake') do set cmake=%%a
if exist "%cmake%" goto check_cmake_version
echo Unable to find cmake %cmake_minversion_minmaj% on this machine.>&2
exit /B -1
:check_cmake_version
rem Get the absolute path of cmake.
for /F "delims=;" %%a in ("%cmake%") do set cmake="%%~da%%~pa%%~na%%~xa"

rem Verify the version of cmake found in the path is the same version or
rem newer than the version this project has been tested against.
set cmake_version=
for /F "tokens=3" %%a in ('%cmake% --version') do set cmake_version=%%a
if "%cmake_version%" == "" (
  echo Unable to get version of cmake %cmake%. >&2
  exit /B 1
)
set cmake_ver_minmaj=
for /F "tokens=1,2 delims=." %%a in ("%cmake_version%") do (
  set cmake_ver_minmaj=%%a.%%b
)
if %cmake_ver_minmaj% LSS %cmake_minversion_minmaj% (
  echo %cmake% %cmake_version% older than required version ^
%cmake_minversion_minmaj% >&2
  exit /B -1
)

rem Determine whether the selected version of visual studio is installed.
if "%visual_studio_version%"=="" (
  reg query ^
    HLKM\SOFTWARE\Microsoft\VisualStudio\%visual_studio_version%.0 /ve ^
    1>NUL 2>NUL
  if ERRORLEVEL 0 (
    goto found_visual_studio
  )
)

rem Determine the newest version of Visual Studio installed on this machine.
setlocal enabledelayedexpansion
set visual_studio_version=
for /L %%a in (%visual_studio_version_max%,-1,%visual_studio_version_min%) do (
  echo Searching for Visual Studio %%a >&2
  reg query HKLM\SOFTWARE\Microsoft\VisualStudio\%%a.0 /ve 1>NUL 2>NUL
  if !ERRORLEVEL! EQU 0 (
    set visual_studio_version=%%a
    goto found_visual_studio
  )
)
endlocal
echo Unable to determine whether Visual Studio is installed. >&2
exit /B 1
:found_visual_studio

rem Map Visual Studio version to cmake generator name.
if "%visual_studio_version%"=="8" (
  set cmake_generator=Visual Studio 8 2005
)
if "%visual_studio_version%"=="9" (
  set cmake_generator=Visual Studio 9 2008
)
if %visual_studio_version GEQ 10 (
  set cmake_generator=Visual Studio %visual_studio_version%
)

rem Generate Visual Studio solution.
cd ..
echo Generating solution for %cmake_generator%. >&2
%cmake% -G"%cmake_generator%"
if %ERRORLEVEL% NEQ 0 (
  exit /B %ERRORLEVEL%
)
rem Build the project.
for %%c in (%build_configuration%) do (
  cd %~d0%~p0/..
  echo Building %solution_to_build% with the %%c configuration. >&2
  AutoBuild\msbuild.bat %msbuild_args% /p:Configuration=%%c %solution_to_build%
)
