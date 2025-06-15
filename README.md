# chroot 환경 자동 구성 스크립트

이 저장소는 리눅스 `chroot` 환경을 쉽고 빠르게 구축하기 위한 쉘 스크립트를 포함하고 있습니다.

chroot 환경을 설정할 때 필요한 명령어와 그에 따른 모든 의존성 라이브러리를 수동으로 복사하는 것은 번거롭고 실수가 잦은 작업입니다. 이 스크립트는 이 과정을 자동화하여, 원하는 명령어 목록만 정의하면 필요한 모든 파일을 chroot 디렉토리 내에 올바른 경로로 복사해줍니다.

## 주요 기능

- **의존성 자동 분석**: `ldd` 명령어를 활용하여 지정된 명령어의 모든 공유 라이브러리 의존성을 자동으로 분석합니다.
- **간편한 설정**: 스크립트 내의 배열(`COMMANDS_TO_ADD`)에 원하는 명령어 이름만 추가하면 되도록 설정이 간편합니다.
- **정확한 경로 생성**: 원본 파일 시스템의 디렉토리 구조를 chroot 환경 내에 그대로 재현하여 파일들을 복사합니다.
- **안전한 반복 실행**: 이미 파일이 존재하는 경우 중복으로 복사하지 않아 여러 번 실행해도 안전합니다.

## 사전 요구 사항

- Bash 쉘
- 기본 리눅스 명령어: `ldd`, `which`, `mkdir`, `cp`, `dirname`

## 사용 방법

1.  **저장소 복제(Clone)**

    ```bash
    git clone https://github.com/garlicKim21/chroot_shellscripts.git
    cd chroot_shellscripts
    ```

2.  **스크립트 설정**

    `setup_chroot.sh` 파일을 열어 `COMMANDS_TO_ADD` 배열에 chroot 환경에 추가하고 싶은 명령어들을 나열합니다.

    ```bash
    # setup_chroot.sh

    # chroot 환경에 추가할 명령어 목록 (이 배열에 원하는 명령어를 추가/삭제하세요)
    COMMANDS_TO_ADD=(
        "ps"
        "mount"
        "mkdir"
        "ls"
        "sh"
        "bash" # 예시: bash 쉘을 추가하고 싶을 경우
        "vi"   # 예시: vi 에디터를 추가하고 싶을 경우
    )
    ```

3.  **스크립트 실행 권한 부여**

    ```bash
    chmod +x setup_chroot.sh
    ```

4.  **스크립트 실행**

    ```bash
    ./setup_chroot.sh
    ```

    스크립트 실행이 완료되면 `CHROOT_DIR` 변수에 지정된 경로(기본값: `/tmp/myroot`)에 chroot 환경이 구성됩니다.

## chroot 환경 실행 예시

스크립트를 통해 `ps`, `mkdir`, `mount` 등의 명령어를 chroot 환경에 설치한 후, `ps` 명령어를 정상적으로 사용하기 위한 전체 과정 예시입니다.

```bash
# 1. (필요시) chroot 환경 안에서 mkdir 명령어로 /proc 디렉토리 생성
sudo chroot /tmp/myroot /bin/mkdir /proc

# 2. 호스트의 /proc 파일시스템을 chroot 환경의 /proc 디렉토리에 바인드 마운트
sudo mount --bind /proc /tmp/myroot/proc

# 3. chroot 환경으로 진입하여 쉘 실행
sudo chroot /tmp/myroot /bin/sh

# --- 이제 chroot 환경 내부입니다 ---

# 4. chroot 내부에서 ps 명령어가 정상 동작하는지 확인
ps aux

# 5. 작업 완료 후 chroot 환경에서 빠져나오기
exit
```

# 라이선스
이 프로젝트는 MIT 라이선스 하에 배포됩니다. 자세한 내용은 [LICENSE](LICENSE) 파일을 참조하세요.
