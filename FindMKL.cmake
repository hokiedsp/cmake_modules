#.rst:
# FindMKL
# -------
# Find the MKL include directory and libraries
#
# The module supports the following components:
#
#    STATIC_LINKING         
#    DYNAMIC_LINKING        
#    RUNTIME_LINKING 
#
#    SEQUENTIAL_THREADING
#    OPENMP_THREADING
#    TBB_THREADING
#
# Only 1 Linking Component (STATIC_LINKING, DYNAMIC_LINKING, or 
# RUNTIME_LINKING) may be specified.
#
# Only 1 Threading Component (SEQUENTIAL_THREADING, OPENMP_THREADING, or 
# TBB_THREADING) may be specified. If multi-threading option (OPENMP_THREADING 
# or TBB_THREADING) is selected, the selected threading library must be added
# separately from MKL.
#
# Module Input Variables
# ^^^^^^^^^^^^^^^^^^^^^^
#
# Users or projects may set the following variables to configure the module
# behaviour:
#
# :variable:`MKL_RUNTIME_ROOT_DIR`
#   the root of the runtime installations.
#
# This module defines
# MKL_INCLUDE_DIR, where to find MKL.h
# MKL_LIBRARY, the library to link against to use MKL.
# MKL_SHAREDLIBRARY
# MKL_FOUND, If false, do not try to use MKL.
# MKL_ROOT, if this module use this path to find MKL header
# and libraries.
#
# In Windows, it looks for MKL_DIR environment variable if defined

# Get native target architecture
include(CheckSymbolExists)
# http://beefchunk.com/documentation/lang/c/pre-defined-c/prearch.html
if(MSVC)
  check_symbol_exists("_M_AMD64" "" RTC_ARCH_X64)
  if(NOT RTC_ARCH_X64)
    check_symbol_exists("_M_IX86" "" RTC_ARCH_X86)
  endif(NOT RTC_ARCH_X64)
  # add check for arm here
  # see http://msdn.microsoft.com/en-us/library/b0084kay.aspx
elseif(MINGW)
    check_symbol_exists("_X86_WIN64_" "" RTC_ARCH_X64)
    if(NOT RTC_ARCH_X64)
    check_symbol_exists("_X86_" "" RTC_ARCH_X86)
    endif(NOT RTC_ARCH_X64)
else(MSVC)
  check_symbol_exists("__x86_64__" "" RTC_ARCH_X64)
  if(NOT RTC_ARCH_X64)
    check_symbol_exists("__i386__" "" RTC_ARCH_X86)
  endif(NOT RTC_ARCH_X64)
endif(MSVC)

if(RTC_ARCH_X64)
  set(ARCH_STR x64)
elseif(RTC_ARCH_X86)
  set(ARCH_STR x86)
else()
  message(FATAL_ERROR "Unknown or unsupported architecture")
endif()

# ###################################

# separate requested components into linking & threading
foreach(component IN LISTS MKL_FIND_COMPONENTS)
  if (component MATCHES .+_LINKING)
    list(APPEND linking_component ${component})
  elseif (component MATCHES .+_THREADING)
    list(APPEND threading_component ${component})
  else()
    message(FATAL_ERROR "Unknown MKL component (${component}) specified.")
  endif()
endforeach(component IN LISTS MKL_FIND_COMPONENTS)

# only 1 LINKING component maybe requested
if (linking_component)
  list(LENGTH linking_component num_comp)
  if (${num_comp} GREATER 1)
    message(FATAL_ERROR "Cannot set multiple LINKING components.")
  endif()
else()
  set(linking_component "DYNAMIC_LINKING") # default linking
endif()

# only 1 LINKING component maybe requested
if (threading_component)
  list(LENGTH threading_component num_comp)
  if (${num_comp} GREATER 1)
    message(FATAL_ERROR "Cannot set multiple THREADING components.")
  endif()
endif (threading_component)
if (threading_component AND (linking_component STREQUAL RUNTIME_LINKING))
    message(FATAL_ERROR "Cannot specify THREADING component with RUNTIME_LINKING component.")
elseif(NOT threading_component)
  set(threading_component "SEQUENTIAL_THREADING") # default threading
endif()

# ###################################

# set MKL_ROOT_DIR in cache if not already done so (Windows only)
if (NOT MKL_ROOT_DIR)
    set(MKL_ROOT_DIR $ENV{MKLROOT} CACHE PATH "MKL installation root path")
endif (NOT MKL_ROOT_DIR)

#####################################

include (GNUInstallDirs) # defines CMAKE_INSTALL_LIBDIR & CMAKE_INSTALL_INCLUDEDIR

# Find header file
find_path(MKL_INCLUDE_DIR MKL.h
    PATHS         ${MKL_ROOT_DIR}
    PATH_SUFFIXES include
    DOC           "Location of MKL header files"
)

if (linking_component STREQUAL RUNTIME_LINKING)
    set(mkl_library_name mkl_rt)
else()
    set(mkl_library_name mkl_core)
    if (RTC_ARCH_X64)
        set(mkl_interface_library_name mkl_intel_ilp64)
    else() # x86
        set(mkl_interface_library_name mkl_intel_c)
    endif()

    if (threading_component STREQUAL SEQUENTIAL_THREADING)
        set(mkl_threading_library_name mkl_sequential)
    elseif (threading_component STREQUAL TBB_THREADING)
        set(mkl_threading_library_name mkl_tbb_thread)
    elseif (threading_component STREQUAL OPENMP_THREADING)
        set(mkl_threading_library_name mkl_intel_thread)
    else()
        message(FATAL_ERROR "Invalid THREADING component.")
    endif()
endif()

if (WIN32 AND linking_component STREQUAL DYNAMIC_LINKING)
    set(mkl_library_name "${mkl_library_name}_dll")
    set(mkl_interface_library_name "${mkl_interface_library_name}_dll")
    set(mkl_threading_library_name "${mkl_threading_library_name}_dll")
endif()

find_library(MKL_LIBRARY ${mkl_library_name}
             PATHS         ${MKL_ROOT_DIR} 
             PATH_SUFFIXES lib/intel64 lib/ia32
             DOC           "MKL core library path")

list(APPEND _req_vars MKL_INCLUDE_DIR MKL_LIBRARY)

if (mkl_interface_library_name)
    find_library(MKL_INTERFACE_LIBRARY ${mkl_interface_library_name}
                PATHS         ${MKL_ROOT_DIR} 
                PATH_SUFFIXES lib/intel64 lib/ia32 lib
                DOC           "MKL interface library path")
    list(APPEND _req_vars MKL_INTERFACE_LIBRARY)
    if(MKL_INTERFACE_LIBRARY)
      set("MKL_${linking_component}_FOUND" true)
    endif()
endif (mkl_interface_library_name)
if (mkl_threading_library_name)
    find_library(MKL_THREADING_LIBRARY ${mkl_threading_library_name}
                PATHS         ${MKL_ROOT_DIR} 
                PATH_SUFFIXES lib/intel64 lib/ia32 lib
                DOC           "MKL threading library path")
    list(APPEND _req_vars MKL_THREADING_LIBRARY)
    if(MKL_THREADING_LIBRARY)
      set("MKL_${threading_component}_FOUND" true)
    endif()
endif (mkl_threading_library_name)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(MKL
    REQUIRED_VARS ${_req_vars}
    HANDLE_COMPONENTS
)

if (MKL_FOUND)
    list(APPEND MKL_INCLUDE_DIRS ${MKL_INCLUDE_DIR})
    list(APPEND MKL_LIBRARIES ${MKL_LIBRARY} ${MKL_INTERFACE_LIBRARY} ${MKL_THREADING_LIBRARY})
endif (MKL_FOUND)

mark_as_advanced(
  MKL_INCLUDE_DIR
  MKL_INTERFACE_LIBRARY
  MKL_LIBRARY
  MKL_THREADING_LIBRARY
)