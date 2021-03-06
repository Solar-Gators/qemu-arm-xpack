# -----------------------------------------------------------------------------
# This file is part of the xPack distribution.
#   (https://xpack.github.io)
# Copyright (c) 2019 Liviu Ionescu.
#
# Permission to use, copy, modify, and/or distribute this software 
# for any purpose is hereby granted, under the terms of the MIT license.
# -----------------------------------------------------------------------------

# Helper script used in the second edition of the GNU MCU Eclipse build 
# scripts. As the name implies, it should contain only functions and 
# should be included with 'source' by the build scripts (both native
# and container).

# -----------------------------------------------------------------------------

function build_qemu() 
{
  if [ ! -d "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}" ]
  then
    (
      xbb_activate

      cd "${WORK_FOLDER_PATH}"
      git_clone "${QEMU_GIT_URL}" "${QEMU_GIT_BRANCH}" \
          "${QEMU_GIT_COMMIT}" "${QEMU_SRC_FOLDER_NAME}"
      cd "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"

      # git submodule update --init --recursive --remote
      # Do not bring all submodules; for better control,
      # prefer to build separate pixman. 
      git submodule update --init dtc

      rm -rf pixman roms

      local patch_file="${BUILD_GIT_PATH}/patches/${QEMU_GIT_PATCH}"
      if [ -f "${patch_file}" ]
      then
        git apply "${patch_file}"
      fi
    )
  fi

  (
    mkdir -pv "${APP_BUILD_FOLDER_PATH}"
    cd "${APP_BUILD_FOLDER_PATH}"

    xbb_activate
    xbb_activate_installed_dev

    CPPFLAGS="${XBB_CPPFLAGS}"
    if [ "${IS_DEBUG}" == "y" ]
    then 
      CPPFLAGS+=" -DDEBUG"
    fi

    CFLAGS="${XBB_CFLAGS_NO_W}"      
    CXXFLAGS="${XBB_CXXFLAGS_NO_W}"

    LDFLAGS="${XBB_LDFLAGS_APP_STATIC_GCC}"
    if [ "${TARGET_PLATFORM}" == "linux" ]
    then
      LDFLAGS+=" -Wl,-rpath,${LD_LIBRARY_PATH}"
    fi      
    if [ "${IS_DEVELOP}" == "y" ]
    then
      LDFLAGS+=" -v"
    fi

    export CPPFLAGS
    export CFLAGS
    export CXXFLAGS
    export LDFLAGS

    env | sort

    (
      if [ ! -f "config.status" ]
      then

        echo
        echo "Overriding version..."
        cp -v "${BUILD_GIT_PATH}/scripts/VERSION" "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}"

        echo
        echo "Running qemu configure..."

        # Although it shouldn't, the script checks python before --help.
        bash "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}/configure" \
          --python=python2 \
          --help

        config_options=()

        config_options+=("--prefix=${APP_PREFIX}")
          
        if [ "${TARGET_PLATFORM}" == "win32" ]
        then
          config_options+=("--cross-prefix=${CROSS_COMPILE_PREFIX}-")
        fi

        config_options+=("--bindir=${APP_PREFIX}/bin")
        config_options+=("--docdir=${APP_PREFIX_DOC}")
        config_options+=("--mandir=${APP_PREFIX_DOC}/man")
          
        config_options+=("--cc=${CC}")
        config_options+=("--cxx=${CXX}")

        config_options+=("--extra-cflags=${CFLAGS} ${CPPFLAGS}")
        config_options+=("--extra-ldflags=${LDFLAGS}")

        config_options+=("--target-list=gnuarmeclipse-softmmu")
      
        config_options+=("--with-sdlabi=2.0")
        config_options+=("--python=python2")

        if [ "${IS_DEBUG}" == "y" ]
        then 
          config_options+=("--enable-debug")
        fi

        config_options+=("--disable-werror")

        config_options+=("--disable-linux-aio")
        config_options+=("--disable-libnfs")
        config_options+=("--disable-snappy")
        config_options+=("--disable-libssh2")
        config_options+=("--disable-gnutls")
        config_options+=("--disable-nettle")
        config_options+=("--disable-lzo")
        config_options+=("--disable-seccomp")
        config_options+=("--disable-bluez")
        config_options+=("--disable-gcrypt")

        if [ "${WITH_STRIP}" != "y" ]
        then
          config_options+=("--disable-strip")
        fi

        run_verbose bash ${DEBUG} "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}/configure" \
          ${config_options[@]}

      fi
      cp "config.log" "${LOGS_FOLDER_PATH}/configure-qemu-log.txt"
    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/configure-qemu-output.txt"

    (
      echo
      echo "Running qemu make..."

      # Build.
      run_verbose make -j ${JOBS}

      run_verbose make install
      run_verbose make install-gme

      (
        xbb_activate_tex

        if [ "${WITH_PDF}" == "y" ]
        then
          make pdf
          make install-pdf
        fi

        if [ "${WITH_HTML}" == "y" ]
        then
          make html
          make install-html
        fi
      )

    ) 2>&1 | tee "${LOGS_FOLDER_PATH}/make-qemu-output.txt"

    copy_license \
      "${WORK_FOLDER_PATH}/${QEMU_SRC_FOLDER_NAME}" \
      "qemu-${QEMU_VERSION}"

  )

  tests_add "test_qemu"
}

function test_qemu()
{
  echo
  echo "Checking the qemu shared libraries..."
  show_libs "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse"

  echo
  echo "Checking if qemu starts..."
  run_app "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" --version
  run_app "${APP_PREFIX}/bin/qemu-system-gnuarmeclipse" --help
}

# -----------------------------------------------------------------------------
