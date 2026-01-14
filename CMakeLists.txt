cmake_minimum_required(VERSION 3.10)
project(sift_gpu_shared LANGUAGES CXX CUDA)

if(NOT DEFINED CMAKE_CUDA_ARCHITECTURES)
    set(CMAKE_CUDA_ARCHITECTURES all-major)
endif()

# 1. Output Setup: Force the .so file to be created in a specific 'lib' folder
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

# 2. Definitions
add_compile_definitions(SIFTGPU_NO_DEVIL)
option(CUDA_ENABLED "Build with CUDA support" ON)

# Hardware acceleration logic
if(SIMD_ENABLED AND IS_X86)
    add_compile_definitions(SIFTGPU_USE_SSE_FOR)
    if(MSVC)
        add_compile_definitions(__SSE__)
    endif()
endif()

# 3. Handle CUDA (if enabled)
set(OPTIONAL_CUDA_SRCS)
set(OPTIONAL_CUDA_LINK_LIBS)

if(CUDA_ENABLED)
    find_package(CUDAToolkit REQUIRED)
    add_compile_definitions(SIFTGPU_CUDA_ENABLED)
    
    set(OPTIONAL_CUDA_SRCS
        CuTexImage.h CuTexImage.cpp
        ProgramCU.cu
        ProgramCU.h
        PyramidCU.h PyramidCU.cpp
        SiftMatchCU.h SiftMatchCU.cpp)
    set(OPTIONAL_CUDA_LINK_LIBS
        CUDA::cudart
        CUDA::curand
    )
endif()

# 4. Handle OpenGL and GLEW (Essential for .so linkage)
find_package(OpenGL REQUIRED)
find_package(GLEW REQUIRED)

# 5. Define the SHARED library (.so)
add_library(sift_gpu SHARED
    FrameBufferObject.h FrameBufferObject.cpp
    GlobalUtil.h GlobalUtil.cpp
    GLTexImage.h GLTexImage.cpp
    ProgramGLSL.h ProgramGLSL.cpp
    ProgramGPU.h
    PyramidGL.h PyramidGL.cpp
    ShaderMan.h ShaderMan.cpp
    SiftGPU.h SiftGPU.cpp
    SiftMatch.h SiftMatch.cpp
    SiftPyramid.h SiftPyramid.cpp
    ${OPTIONAL_CUDA_SRCS}
)

# 6. Set properties for Shared Library
set_target_properties(sift_gpu PROPERTIES 
    POSITION_INDEPENDENT_CODE ON
    # This ensures the library is named libsift_gpu.so on Linux
    CUDA_SEPARABLE_COMPILATION ON
    PREFIX "lib"
    SUFFIX ".so"
)

# 7. Linkage and Includes
# PUBLIC means any project linking to sift_gpu gets these includes/libs too
target_include_directories(sift_gpu PUBLIC ${CMAKE_CURRENT_SOURCE_DIR})

target_link_libraries(sift_gpu
    PUBLIC
        OpenGL::GL
        GLEW::GLEW
        ${OPTIONAL_CUDA_LINK_LIBS}
)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

# Make includes correct for both build-tree and install-tree consumers
target_include_directories(sift_gpu PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}>
  $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
)

# Install the shared library
install(TARGETS sift_gpu
  EXPORT SiftGPUTargets
  LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
  ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
  RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
  INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

# Install headers (simple approach: all .h in source dir)
install(DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
  DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/SiftGPU
  FILES_MATCHING PATTERN "*.h"
)

# ---- CMake package config (for find_package) ----
set(SIFTGPU_CMAKE_DIR "${CMAKE_INSTALL_LIBDIR}/cmake/SiftGPU")

# Create Config + Version files
configure_package_config_file(
  "${CMAKE_CURRENT_SOURCE_DIR}/cmake/SiftGPUConfig.cmake.in"
  "${CMAKE_CURRENT_BINARY_DIR}/SiftGPUConfig.cmake"
  INSTALL_DESTINATION ${SIFTGPU_CMAKE_DIR}
)

write_basic_package_version_file(
  "${CMAKE_CURRENT_BINARY_DIR}/SiftGPUConfigVersion.cmake"
  VERSION 1.0
  COMPATIBILITY SameMajorVersion
)

# Install exports + config files
install(EXPORT SiftGPUTargets
  NAMESPACE SiftGPU::
  DESTINATION ${SIFTGPU_CMAKE_DIR}
)

install(FILES
  "${CMAKE_CURRENT_BINARY_DIR}/SiftGPUConfig.cmake"
  "${CMAKE_CURRENT_BINARY_DIR}/SiftGPUConfigVersion.cmake"
  DESTINATION ${SIFTGPU_CMAKE_DIR}
)
