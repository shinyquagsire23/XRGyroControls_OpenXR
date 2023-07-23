#!/bin/zsh
PWD=$(pwd)

# Be sure to follow https://gist.github.com/shinyquagsire23/3c68aecd872cc7ac21c28e950245dbd2

# Monado build config
#cmake .. -DXRT_ENABLE_GPL=1 -DXRT_BUILD_DRIVER_EUROC=0 -DXRT_BUILD_DRIVER_NS=0 -DXRT_BUILD_DRIVER_PSVR=0 -DXRT_HAVE_OPENCV=0 -DXRT_HAVE_XCB=0 -DXRT_HAVE_XLIB=0 -DXRT_HAVE_XRANDR=0 -DXRT_HAVE_SDL2=0  -DXRT_HAVE_VT=0 -DXRT_FEATURE_WINDOW_PEEK=0 -DXRT_BUILD_DRIVER_QWERTY=0

# These env vars can interfere w/ building
unset MACOSX_DEPLOYMENT_TARGET

if ! [[ -d "libusb" ]]; then
    mkdir -p libusb
    pushd libusb
    git init
    git remote add origin https://github.com/libusb/libusb.git
    git fetch --depth 1 origin 8450cc93f6c8747a36a9ee246708bf650bb762a8
    git checkout FETCH_HEAD
    git apply --whitespace=fix ../libusb.patch
    ./bootstrap.sh
    ./configure
    popd
fi

pushd libusb
make
retVal=$?
if [ $retVal -ne 0 ]; then
    exit $retVal
fi
popd

# Build, and if it errors then abort
cmake -B build -D CMAKE_BUILD_TYPE=RelWithDebInfo -D BUILD_TESTING=YES -G Ninja -S .
ninja -C build -v
retVal=$?
if [ $retVal -ne 0 ]; then
    exit $retVal
fi

# Compile all the shaders
mkdir -p shaders && cp openxr_src/shaders/* shaders/ && cd $PWD && \
glslc --target-env=vulkan1.2 $PWD/shaders/Basic.vert -std=450core -O -o $PWD/shaders/Basic.vert.spv && \
glslc --target-env=vulkan1.2 $PWD/shaders/Rect.frag -std=450core -O -o $PWD/shaders/Rect.frag.spv

cp build/libSim2OpenXR.dylib libSim2OpenXR.dylib

# Remove old sim stuff
rm -rf /Applications/Xcode-beta.app/Contents/Developer/Platforms/XROS.platform/Library/Developer/CoreSimulator/Profiles/UserInterface/XRGyroControls.simdeviceui

# otool -L is your friend, make sure there's nothing weird
function fixup_dependency ()
{
    which_dylib=$1
    vtool_src=$2
    vtool_dst=$(basename $2)
    vtool -remove-build-version macos -output $vtool_dst $vtool_src
    vtool -set-build-version xrossim 1.0 1.0 -tool ld 902.11 -output $vtool_dst $vtool_dst
    install_name_tool -change @rpath/$vtool_dst $(pwd)/$vtool_dst $which_dylib
    install_name_tool -change $vtool_src $(pwd)/$vtool_dst $which_dylib

    # Every framework has to be changed to remove "Versions/A/".
    # You can also swap out frameworks for interposing dylibs here.
    install_name_tool -change /System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation /System/Library/Frameworks/CoreFoundation.framework/CoreFoundation $vtool_dst
    install_name_tool -change /System/Library/Frameworks/Security.framework/Versions/A/Security /System/Library/Frameworks/Security.framework/Security $vtool_dst
    install_name_tool -change /System/Library/Frameworks/IOKit.framework/Versions/A/IOKit /System/Library/Frameworks/IOKit.framework/IOKit $vtool_dst
    #install_name_tool -change /System/Library/Frameworks/IOKit.framework/Versions/A/IOKit $(pwd)/IOKit_arm64.dylib $vtool_dst

    install_name_tool -change /System/Library/Frameworks/Metal.framework/Versions/A/Metal /System/Library/Frameworks/Metal.framework/Metal $vtool_dst
    install_name_tool -change /System/Library/Frameworks/IOSurface.framework/Versions/A/IOSurface /System/Library/Frameworks/IOSurface.framework/IOSurface $vtool_dst
    install_name_tool -change /System/Library/Frameworks/AppKit.framework/Versions/C/AppKit /System/Library/Frameworks/AppKit.framework/AppKit $vtool_dst
    install_name_tool -change /System/Library/Frameworks/QuartzCore.framework/Versions/A/QuartzCore /System/Library/Frameworks/QuartzCore.framework/QuartzCore $vtool_dst
    install_name_tool -change /System/Library/Frameworks/CoreGraphics.framework/Versions/A/CoreGraphics /System/Library/Frameworks/CoreGraphics.framework/CoreGraphics $vtool_dst
    install_name_tool -change /System/Library/Frameworks/Foundation.framework/Versions/C/Foundation /System/Library/Frameworks/Foundation.framework/Foundation $vtool_dst
    install_name_tool -change /System/Library/PrivateFrameworks/SoftLinking.framework/Versions/A/SoftLinking /System/Library/PrivateFrameworks/SoftLinking.framework/SoftLinking $vtool_dst
    install_name_tool -change /System/Library/Frameworks/VideoToolbox.framework/Versions/A/VideoToolbox /System/Library/Frameworks/VideoToolbox.framework/VideoToolbox $vtool_dst
    install_name_tool -change /System/Library/Frameworks/CoreServices.framework/Versions/A/CoreServices /System/Library/Frameworks/CoreServices.framework/CoreServices $vtool_dst
    install_name_tool -change /System/Library/Frameworks/CoreMedia.framework/Versions/A/CoreMedia /System/Library/Frameworks/CoreMedia.framework/CoreMedia $vtool_dst
    install_name_tool -change /System/Library/Frameworks/CoreVideo.framework/Versions/A/CoreVideo /System/Library/Frameworks/CoreVideo.framework/CoreVideo $vtool_dst

    codesign -s - $vtool_dst --force --deep --verbose
}

# *slow chanting* hacks, hacks, HACKS **HACKS**
fixup_dependency libSim2OpenXR.dylib /opt/homebrew/lib/libopenxr_loader.dylib
fixup_dependency libSim2OpenXR.dylib $MONADO_BUILD_DIR/src/xrt/targets/openxr/libopenxr_monado.dylib
fixup_dependency libSim2OpenXR.dylib $VULKAN_SDK/lib/libvulkan.1.dylib
fixup_dependency libSim2OpenXR.dylib $VULKAN_SDK/../MoltenVK/dylib/iOS/libMoltenVK.dylib
fixup_dependency libSim2OpenXR.dylib /opt/homebrew/opt/glfw/lib/libglfw.3.dylib
fixup_dependency libSim2OpenXR.dylib /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib

#
# libopenxr_monado.dylib fixups
#
#fixup_dependency libopenxr_monado.dylib /opt/homebrew/opt/hidapi/lib/libhidapi.0.dylib
fixup_dependency libopenxr_monado.dylib /opt/homebrew/opt/libusb/lib/libusb-1.0.0.dylib
fixup_dependency libopenxr_monado.dylib libusb/libusb/.libs/libusb-1.0.0.dylib
fixup_dependency libopenxr_monado.dylib /opt/homebrew/opt/x264/lib/libx264.164.dylib
fixup_dependency libopenxr_monado.dylib $VULKAN_SDK/lib/libvulkan.1.dylib
fixup_dependency libopenxr_monado.dylib $VULKAN_SDK/../MoltenVK/dylib/iOS/libMoltenVK.dylib
fixup_dependency libopenxr_monado.dylib /opt/homebrew/opt/cjson/lib/libcjson.1.dylib
fixup_dependency libopenxr_monado.dylib /opt/homebrew/opt/jpeg-turbo/lib/libjpeg.8.dylib

# Pulled from iPhone X recovery ramdisk, some patches were done in a hex editor.
vtool -remove-build-version macos -output  IOUSBLib_ios_hax.dylib IOUSBLib_ios_hax.dylib
vtool -remove-build-version ios -output  IOUSBLib_ios_hax.dylib IOUSBLib_ios_hax.dylib
vtool -set-build-version xrossim 1.0 1.0 -tool ld 902.11 -output IOUSBLib_ios_hax.dylib IOUSBLib_ios_hax.dylib
codesign -s - IOUSBLib_ios_hax.dylib --force --deep --verbose

# Fixup libusb bc we don't actually use the homebrew one
vtool -remove-build-version macos -output libusb-1.0.0.dylib libusb-1.0.0.dylib 
vtool -set-build-version xrossim 1.0 1.0 -tool ld 902.11 -output libusb-1.0.0.dylib libusb-1.0.0.dylib 
codesign -s - libusb-1.0.0.dylib --force --deep --verbose

#vtool -remove-build-version ios -output  IOUSBLib_ios_macos.dylib IOUSBLib_ios_macos.dylib
#vtool -set-build-version macos 14.0 14.0 -tool ld 902.8 -output IOUSBLib_ios_macos.dylib IOUSBLib_ios_macos.dylib
#codesign -s - IOUSBLib_ios_macos.dylib --force --deep --verbose

cp libMoltenVK_iossim.dylib libMoltenVK.dylib
fixup_dependency libMoltenVK.dylib libMoltenVK.dylib
#vtool_src=libvulkan.1.dylib
#vtool_dst=libvulkan.1.dylib
#vtool -remove-build-version macos -output $vtool_dst $vtool_src
#vtool -set-build-version xrossim 1.0 1.0 -tool ld 902.11 -output $vtool_dst $vtool_dst

# Sign everything just in case (it complains anyway)
codesign -s - libopenxr_loader.dylib --force --deep --verbose
codesign -s - libopenxr_monado.dylib --force --deep --verbose
codesign -s - libvulkan.1.dylib --force --deep --verbose
codesign -s - libSim2OpenXR.dylib --force --deep --verbose

# Fixup monado JSON
gsed "s|REPLACE_ME|$PWD|g" openxr_monado-dev.json.template > openxr_monado-dev.json




#
# SimUI stuff
#

# Couldn't figure out how to do this with CMake, but everything gets dynamically linked so it doesn't particularly matter and we can fixup the rpaths
install_name_tool -change @rpath/libSimulatorKit.dylib  @rpath/SimulatorKit.framework/Versions/A/SimulatorKit build/libXRGyroControls.dylib
mkdir -p XRGyroControls.simdeviceui/Contents/MacOS/
cp build/libXRGyroControls.dylib XRGyroControls.simdeviceui/Contents/MacOS/XRGyroControls

# Sign just in case (it complains anyway)
codesign -s - XRGyroControls.simdeviceui --force --deep --verbose

# Copy to CoreSimulator
rm -rf /Applications/Xcode-beta.app/Contents/Developer/Platforms/XROS.platform/Library/Developer/CoreSimulator/Profiles/UserInterface/XRGyroControls.simdeviceui
cp -r XRGyroControls.simdeviceui /Applications/Xcode-beta.app/Contents/Developer/Platforms/XROS.platform/Library/Developer/CoreSimulator/Profiles/UserInterface/XRGyroControls.simdeviceui