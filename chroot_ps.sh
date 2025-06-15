#!/bin/bash

# --- 설정 ---
# chroot 환경으로 사용할 디렉토리 경로
CHROOT_DIR="/tmp/myroot"

# chroot 환경에 추가할 명령어 목록 (이 배열에 원하는 명령어를 추가/삭제하세요)
COMMANDS_TO_ADD=(
    "ps"
    "mount"
    "mkdir"
    "ls"
    "sh"
)
# ----------------

# chroot 환경 내에서 명령어를 모아둘 디렉토리
CHROOT_BIN_DIR="${CHROOT_DIR}/bin"

echo "chroot 환경 설정을 시작합니다: ${CHROOT_DIR}"
echo "----------------------------------------"

# chroot 내의 /bin 디렉토리가 없으면 미리 생성
mkdir -p "${CHROOT_BIN_DIR}"

# 명령어 목록을 순회하며 하나씩 처리
for CMD in "${COMMANDS_TO_ADD[@]}"; do
    echo ">>> 처리 중인 명령어: [${CMD}]"

    # 1. 명령어의 전체 경로 찾기 (e.g. "ps" -> "/usr/bin/ps")
    TARGET_CMD=$(which "${CMD}")
    
    # which 명령어로 경로를 찾지 못하면 경고 후 건너뜀
    if [ -z "${TARGET_CMD}" ]; then
        echo "    [경고] '${CMD}' 명령어를 시스템에서 찾을 수 없습니다. 건너뜁니다."
        echo ""
        continue
    fi

    # 2. 명령어 실행 파일 복사
    cp "${TARGET_CMD}" "${CHROOT_BIN_DIR}/"
    echo "  - 실행 파일 복사: ${TARGET_CMD} -> ${CHROOT_BIN_DIR}/"

    # 3. 의존성 라이브러리 파일 복사
    echo "  - 의존성 라이브러리 복사:"
    
    # ldd 명령어로 의존성을 확인하고, awk로 필요한 라이브러리 경로만 추출
    # 중복 복사를 피하기 위해 이미 파일이 존재하면 건너뜀
    for LIB in $(ldd "${TARGET_CMD}" | awk '/=>/ {print $3} /ld-linux/ {print $1}'); do
        DEST_LIB_PATH="${CHROOT_DIR}${LIB}"
        
        if [ -e "${DEST_LIB_PATH}" ]; then
            # echo "    - (이미 존재함) ${LIB}" # 이미 있는 파일은 메시지 생략
            : # 아무것도 안함
        else
            DEST_LIB_DIR=$(dirname "${DEST_LIB_PATH}")
            mkdir -p "${DEST_LIB_DIR}"
            cp "${LIB}" "${DEST_LIB_DIR}/"
            echo "    - (신규 복사) ${LIB}"
        fi
    done
    echo "" # 각 명령어 처리 후 줄바꿈
done

echo "----------------------------------------"
echo "모든 명령어와 의존성 설정이 완료되었습니다!"
