# Linker settings and system libraries for every platform.

# Ninja only. Each executable link peaks at several GB, so cap how many run beside the compiles.
set_property(GLOBAL APPEND PROPERTY JOB_POOLS link=2)
set(CMAKE_JOB_POOL_LINK link)

# Find Threads (pthread)
set(THREADS_PREFER_PTHREAD_FLAG ON)
find_package(Threads REQUIRED)
link_libraries(${CMAKE_THREAD_LIBS_INIT})

if(MSVC)
    foreach(config RELEASE RELWITHDEBINFO MINSIZEREL)
        string(APPEND CMAKE_EXE_LINKER_FLAGS_${config}
            " /INCREMENTAL:NO" # a full link; incremental linking pads the exe and fights /OPT
            " /OPT:REF"        # drop unreferenced functions and data
            " /OPT:ICF"        # fold identical functions
        )
    endforeach()

    link_libraries(
        ws2_32
        dbghelp
        winmm
        shlwapi
        shell32
        user32
    )
endif()

if(UNIX)
    link_libraries(dl) # dlopen, used by LuaJIT and the crash trace libraries
endif()

# XI: Forever Offline player build for Linux (-DXI_PORTABLE_LINUX=ON): the C++ runtime is
# linked in, and the programs look for the other libraries in ./lib beside them first, so
# one build runs on SteamOS and most desktop distros (glibc of the build machine or newer).
option(XI_PORTABLE_LINUX "Portable Linux player build (static libstdc++, ./lib rpath)" OFF)
if(UNIX AND NOT APPLE AND XI_PORTABLE_LINUX)
    if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        # Clang with its own C++ library (libc++), linked in with its ABI library: GCC 14's libstdc++ can't build
        # this C++23 code with Clang, and GCC 15 isn't on older distros. Needs LLD (-DCMAKE_LINKER_TYPE=LLD).
        add_compile_options($<$<COMPILE_LANGUAGE:CXX>:-stdlib=libc++>)
        add_link_options(-stdlib=libc++ -Wl,-Bstatic -lc++abi -Wl,-Bdynamic)
    endif()
    add_link_options(-static-libstdc++ -static-libgcc
        -Wl,--disable-new-dtags)   # DT_RPATH, not RUNPATH: the libraries in ./lib find each other there too
    set(CMAKE_BUILD_RPATH "\$ORIGIN/lib")
    set(CMAKE_INSTALL_RPATH "\$ORIGIN/lib")
    set(CMAKE_BUILD_WITH_INSTALL_RPATH ON)
endif()

if(APPLE)
    # The modern Apple linker (ld_prime, Xcode 15+) warns when the same library
    # appears more than once on the link line. CMake's dependency propagation
    # legitimately repeats static libs (historically required by classic ld64),
    # so the warning is pure noise: silence it where the linker supports the flag.
    include(CheckLinkerFlag)
    check_linker_flag(CXX "-Wl,-no_warn_duplicate_libraries" LINKER_SUPPORTS_NO_WARN_DUPLICATE_LIBRARIES)
    if(LINKER_SUPPORTS_NO_WARN_DUPLICATE_LIBRARIES)
        add_link_options("-Wl,-no_warn_duplicate_libraries")
    endif()
endif()
