#################################################################
#    SiftGPU congiruation:  CUDA, SSE, TIMING  
#################################################################
#enable siftgpu server
siftgpu_enable_server = 0
#enable OpenCL-based SiftGPU? not finished yet; testing purpose
siftgpu_enable_opencl = 0
#------------------------------------------------------------------------------------------------
# enable CUDA-based SiftGPU?
simple_find_cuda := $(shell type nvcc>/dev/null 2>&1; echo $$?)
$(info ----- value $(simple_find_cuda) -----)
ifeq ($(simple_find_cuda), 0)
 	siftgpu_enable_cuda = 1
else
	siftgpu_enable_cuda = 0
endif
siftgpu_enable_cuda = 1

CUDA_INSTALL_PATH = /usr/local/cuda
#change  additional  settings, like SM version here if it is not 1.0 (eg. -arch sm_13 for GTX280)
#siftgpu_cuda_options = -Xopencc -OPT:unroll_size=200000
#siftgpu_cuda_options = -arch sm_10
#--------------------------------------------------------------------------------------------------
# enable SSE optimization for GL-based implementations
siftgpu_enable_sse = 1
siftgpu_sse_options = -march=core2 -mfpmath=sse
#--------------------------------------------------------------------------------------------------
# openGL context creation.  1 for glut, 0 for xlib
siftgpu_prefer_glut = 1
#whether remove dependency on DevIL (1 to remove, the output libsiftgpu.so still works for VisualSFM)
siftgpu_disable_devil = 0
#------------------------------------------------------------------------------------------------
#whether SimpleSIFT uses runtime loading of libsiftgpu.so or static linking of libsiftgpu.a
simplesift_runtime_load = 1

#################################################################


# cleanup trailing whitespaces for a few settings
siftgpu_enable_cuda := $(strip $(siftgpu_enable_cuda))
siftgpu_disable_devil := $(strip $(siftgpu_disable_devil))
siftgpu_enable_server := $(strip $(siftgpu_enable_server))
siftgpu_enable_opencl := $(strip $(siftgpu_enable_opencl))
siftgpu_prefer_glut := $(strip $(siftgpu_prefer_glut))
simplesift_runtime_load := $(strip $(simplesift_runtime_load))

# detect OS
OSUPPER = $(shell uname -s 2>/dev/null | tr [:lower:] [:upper:])
OSLOWER = $(shell uname -s 2>/dev/null | tr [:upper:] [:lower:])
DARWIN = $(strip $(findstring DARWIN, $(OSUPPER)))


SHELL = /bin/sh
INC_DIR = include
BIN_DIR = bin
SRC_SIFTGPU = src/SiftGPU
SRC_DRIVER = src/TestWin
SRC_SERVER = src/ServerSiftGPU
CC = g++
CFLAGS = -I$(INC_DIR) -fPIC  -L/usr/lib -L./bin -L./lib -Wall -Wno-deprecated -pthread  

#simple hack to repalce the native flat on OSX because gcc version is low
ifneq ($(DARWIN),) 
	siftgpu_sse_options = -march=core2 -mfpmath=sse
endif

ifneq ($(siftgpu_enable_sse), 0)
 	CFLAGS += $(siftgpu_sse_options)
endif

ifneq ($(siftgpu_prefer_glut), 0)
	CFLAGS += -DWINDOW_PREFER_GLUT
endif

ifneq ($(siftgpu_enable_opencl), 0)
	CFLAGS += -DCL_SIFTGPU_ENABLED
endif

ODIR_SIFTGPU = build


# external header files
_HEADER_EXTERNAL = GL/glew.h GL/glut.h IL/il.h  
# siftgpu header files
_HEADER_SIFTGPU = FrameBufferObject.h GlobalUtil.h GLTexImage.h ProgramGPU.h ShaderMan.h ProgramGLSL.h SiftGPU.h SiftPyramid.h SiftMatch.h PyramidGL.h LiteWindow.h
# siftgpu library header files for drivers
_HEADER_SIFTGPU_LIB = SiftGPU.h  

ifneq ($(DARWIN),) 
#librarys for SiftGPU
LIBS_SIFTGPU = -lGLEW -framework GLUT -framework OpenGL 
CFLAGS +=  -L/Users/prb2pal/Development/Resources/lib  
else
#librarys for SiftGPU
LIBS_SIFTGPU = -lGLEW -lglut -lGL -lX11
endif
 
ifneq ($(siftgpu_disable_devil), 0)
	CFLAGS += -DSIFTGPU_NO_DEVIL
else
	LIBS_SIFTGPU += -lIL
endif 
 
#Obj files for SiftGPU
_OBJ_SIFTGPU = FrameBufferObject.o GlobalUtil.o GLTexImage.o ProgramGLSL.o ProgramGPU.o ShaderMan.o SiftGPU.o SiftPyramid.o PyramidGL.o SiftMatch.o

#add cuda options
ifneq ($(siftgpu_enable_cuda), 0)
	ifdef CUDA_BIN_PATH
		NVCC = $(CUDA_BIN_PATH)/nvcc
	else
		NVCC = $(CUDA_INSTALL_PATH)/bin/nvcc
	endif

	ifndef CUDA_INC_PATH
		CUDA_INC_PATH = $(CUDA_INSTALL_PATH)/include
	endif

	ifndef CUDA_LIB_PATH
		CUDA_LIB_PATH = $(CUDA_INSTALL_PATH)/lib64 -L$(CUDA_INSTALL_PATH)/lib
	endif

	CFLAGS += -DCUDA_SIFTGPU_ENABLED -I$(CUDA_INC_PATH) -L$(CUDA_LIB_PATH)
	LIBS_SIFTGPU += -lcudart
	_OBJ_SIFTGPU += CuTexImage.o PyramidCU.o SiftMatchCU.o
	_HEADER_SIFTGPU += CuTexImage.h ProgramCU.h PyramidCU.h
endif
 
ifneq ($(siftgpu_enable_opencl), 0)
	CFLAGS += -lOpenCL
endif
 
all: makepath siftgpu server  driver 
 

#the dependencies of SiftGPU library 
DEPS_SIFTGPU = $(patsubst %, $(SRC_SIFTGPU)/%, $(_HEADER_SIFTGPU))


#rules for the rest of the object files
$(ODIR_SIFTGPU)/%.o: $(SRC_SIFTGPU)/%.cpp $(DEPS_SIFTGPU) 
	$(CC) -o $@ $< $(CFLAGS) -c 


ifneq ($(siftgpu_enable_cuda), 0)
NVCC_FLAGS = -I$(INC_DIR) -I$(CUDA_INC_PATH) -DCUDA_SIFTGPU_ENABLED -O2 -Xcompiler -fPIC
ifdef siftgpu_cuda_options
	NVCC_FLAGS += $(siftgpu_cuda_options)
endif
#build rule for CUDA 
$(ODIR_SIFTGPU)/ProgramCU.o: $(SRC_SIFTGPU)/ProgramCU.cu $(DEPS_SIFTGPU)
	$(NVCC) $(NVCC_FLAGS) -o $@ $< -c
_OBJ_SIFTGPU += ProgramCU.o
endif


ifneq ($(siftgpu_enable_server), 0)
$(ODIR_SIFTGPU)/ServerSiftGPU.o: $(SRC_SERVER)/ServerSiftGPU.cpp $(DEPS_SIFTGPU)
	$(CC) -o $@ $< $(CFLAGS) -DSERVER_SIFTGPU_ENABLED -c
_OBJ_SIFTGPU += ServerSiftGPU.o
endif

OBJ_SIFTGPU = $(patsubst %,$(ODIR_SIFTGPU)/%,$(_OBJ_SIFTGPU))
LIBS_DRIVER = $(BIN_DIR)/libsiftgpu.a $(LIBS_SIFTGPU) 
SRC_TESTWIN = $(SRC_DRIVER)/TestWinGlut.cpp $(SRC_DRIVER)/BasicTestWin.cpp  
DEP_TESTWIN = $(SRC_DRIVER)/TestWinGlut.h $(SRC_DRIVER)/BasicTestwin.h $(SRC_DRIVER)/GLTransform.h 



ifneq ($(simplesift_runtime_load), 0)
LIBS_SIMPLESIFT = -ldl -DSIFTGPU_DLL_RUNTIME
else
LIBS_SIMPLESIFT = $(LIBS_DRIVER) -DSIFTGPU_STATIC
endif

siftgpu: makepath $(OBJ_SIFTGPU)
	ar rcs $(BIN_DIR)/libsiftgpu.a $(OBJ_SIFTGPU)
	$(CC) -o $(BIN_DIR)/libsiftgpu.so $(OBJ_SIFTGPU) $(LIBS_SIFTGPU) $(CFLAGS) -shared -fPIC
 
driver: makepath 
	$(CC) -o $(BIN_DIR)/TestWinGlut $(SRC_TESTWIN) $(LIBS_DRIVER) $(CFLAGS)
	$(CC) -o $(BIN_DIR)/SimpleSIFT $(SRC_DRIVER)/SimpleSIFT.cpp $(LIBS_SIMPLESIFT) $(CFLAGS) 
	$(CC) -o $(BIN_DIR)/speed $(SRC_DRIVER)/speed.cpp $(LIBS_DRIVER) $(CFLAGS) 
	$(CC) -o $(BIN_DIR)/MultiThreadSIFT $(SRC_DRIVER)/MultiThreadSIFT.cpp $(LIBS_DRIVER) $(CFLAGS)  -pthread
	
ifneq ($(siftgpu_enable_server), 0)
server: makepath
	$(CC) -o $(BIN_DIR)/server_siftgpu $(SRC_SERVER)/server.cpp $(LIBS_DRIVER) $(CFLAGS)
else
server: 

endif	
	
makepath:
	mkdir -p $(ODIR_SIFTGPU)
	mkdir -p $(BIN_DIR) 
	sed -i -e 's/\\/\//g' demos/*.bat

# -----------------------------
# Installation (for CMake find_package)
# -----------------------------
PREFIX        ?= /usr/local
LIBDIR        ?= $(PREFIX)/lib
INCLUDEDIR    ?= $(PREFIX)/include/SiftGPU
CMAKEDIR      ?= $(LIBDIR)/cmake/SiftGPU

# If you want to version your .so later, you can add SONAME/versioning,
# but keep it simple for now.

install: siftgpu
	install -d "$(DESTDIR)$(LIBDIR)" "$(DESTDIR)$(INCLUDEDIR)" "$(DESTDIR)$(CMAKEDIR)"
	# libraries
	install -m 755 "$(BIN_DIR)/libsiftgpu.so" "$(DESTDIR)$(LIBDIR)/libsiftgpu.so"
	install -m 644 "$(BIN_DIR)/libsiftgpu.a"  "$(DESTDIR)$(LIBDIR)/libsiftgpu.a"
	# public header(s)
	install -m 644 "$(SRC_SIFTGPU)/SiftGPU.h" "$(DESTDIR)$(INCLUDEDIR)/SiftGPU.h"

	# CMake package config so consumers can do: find_package(SiftGPU CONFIG REQUIRED)
	cat > "$(DESTDIR)$(CMAKEDIR)/SiftGPUConfig.cmake" <<'EOF'
# Minimal CMake package config for SiftGPU built by a Makefile install.
# Usage in consumer:
#   find_package(SiftGPU CONFIG REQUIRED)
#   target_link_libraries(yourTarget PRIVATE SiftGPU::siftgpu)

get_filename_component(_SIFTGPU_PREFIX "\${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

add_library(SiftGPU::siftgpu SHARED IMPORTED GLOBAL)
set_target_properties(SiftGPU::siftgpu PROPERTIES
  IMPORTED_LOCATION "\${_SIFTGPU_PREFIX}/lib/libsiftgpu.so"
  INTERFACE_INCLUDE_DIRECTORIES "\${_SIFTGPU_PREFIX}/include/SiftGPU"
)

# Link dependencies. Keep as linker flags to avoid requiring extra CMake packages.
# Adjust if your build differs (e.g., DevIL disabled/enabled, CUDA on/off).
if(APPLE)
  target_link_libraries(SiftGPU::siftgpu INTERFACE
    -lGLEW
    -framework GLUT
    -framework OpenGL
  )
else()
  target_link_libraries(SiftGPU::siftgpu INTERFACE
    -lGLEW -lglut -lGL -lX11
  )
endif()

# DevIL (only if you build with it)
# If you set siftgpu_disable_devil=1, you can remove this line.
target_link_libraries(SiftGPU::siftgpu INTERFACE -lIL)

# CUDA runtime (only if you build with CUDA)
# If you build without CUDA, you can remove this line.
target_link_libraries(SiftGPU::siftgpu INTERFACE -lcudart)
EOF

	# Optional: a version file so CMake doesn't complain if someone uses find_package(... VERSION ...)
	cat > "$(DESTDIR)$(CMAKEDIR)/SiftGPUConfigVersion.cmake" <<'EOF'
set(PACKAGE_VERSION "0.0.0")
if(PACKAGE_FIND_VERSION)
  set(PACKAGE_VERSION_COMPATIBLE TRUE)
  set(PACKAGE_VERSION_EXACT FALSE)
endif()
EOF

	@echo "Installed SiftGPU to $(DESTDIR)$(PREFIX)"
	@echo "On Linux you may need: sudo ldconfig"

uninstall:
	rm -f "$(DESTDIR)$(LIBDIR)/libsiftgpu.so" "$(DESTDIR)$(LIBDIR)/libsiftgpu.a"
	rm -f "$(DESTDIR)$(INCLUDEDIR)/SiftGPU.h"
	rm -f "$(DESTDIR)$(CMAKEDIR)/SiftGPUConfig.cmake" "$(DESTDIR)$(CMAKEDIR)/SiftGPUConfigVersion.cmake"
	rmdir --ignore-fail-on-non-empty "$(DESTDIR)$(CMAKEDIR)" "$(DESTDIR)$(INCLUDEDIR)" 2>/dev/null || true

clean:
	rm -f $(ODIR_SIFTGPU)/*.o
	rm -f $(BIN_DIR)/libsiftgpu.a
	rm -f $(BIN_DIR)/libsiftgpu.so
	rm -f $(BIN_DIR)/TestWinGlut
	rm -f $(BIN_DIR)/SimpleSIFT
	rm -f $(BIN_DIR)/speed
	rm -f $(BIN_DIR)/server_siftgpu
	rm -f $(BIN_DIR)/MultiThreadSIFT
	rm -f ProgramCU.linkinfo

