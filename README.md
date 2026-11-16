# GB4P libfprint egismoc (1c7a:05a1) SDCP 패치

갤럭시 북4 프로(Egis `1c7a:05a1`, ETU905A80-E)용 libfprint egismoc SDCP 패치, 빌드된 라이브러리, 복원 스크립트, 작업 기록 모음입니다.

> **상태: 보관(archived), 유지보수 안 함.**
> 지문인식은 Windows에서 순정 드라이버로만 쓰고, Ubuntu에서는 지문인식 대신 다른 간편 로그인(biopass 얼굴인식)을 씁니다.
> 이 레포는 [GB4P_ubuntu_my_preferences](https://github.com/hajunlee213/GB4P_ubuntu_my_preferences)에서 분리했고, 해당 파일들의 git 기록은 그대로 남아 있습니다.

## 출처

- 코드 베이스: [TenSeventy7/libfprint-egismoc-sdcp](https://github.com/TenSeventy7/libfprint-egismoc-sdcp) `master` (`4d128d4`)
- 설치 스크립트 참고: [antoskuu/libfprint-egismoc-sdcp-fix](https://github.com/antoskuu/libfprint-egismoc-sdcp-fix)
- 05a1 관찰 결과를 공유한 코멘트: [TenSeventy7/libfprint-egismoc-sdcp PR #17](https://github.com/TenSeventy7/libfprint-egismoc-sdcp/pull/17#issuecomment-6913965276)

## 패치 요약 (v2)

`gb4p-05a1-sdcp-v2.patch` (`4d128d4` 기준 `git am`으로 적용):

1. `fpi-sdcp-device.c`: 재부팅 후에도 캐시된 host key를 버리지 않음. 05a1은 키가 바뀌면 등록 지문이 0개로 나옴.
2. `fpi-sdcp-device.c`: 캐시를 불러올 때 항상 `is_connected = FALSE`로 설정. open할 때마다 같은 키로 `SDCP Connect`를 새로 맺음 (잠금/절전 뒤 `65 E0` 방지).
3. `egismoc.c`: `claim_expiration_seconds = -1`. 24시간 만료로 키가 다시 만들어지지 않게 함. 임시방편임.
4. `egismoc.c`: `egismoc_close()`에서 남은 `task_ssm`을 해제. 인증 취소 뒤 fprintd가 죽는 문제 회피. 근본 수정은 PR #17 참고.

"05a1이 지문 템플릿을 host key에 묶는다"는 테스트 결과에서 추론한 것이고, 펌웨어로 확인한 사실은 아닙니다.

## 구성

| 경로 | 내용 |
| :--- | :--- |
| `gb4p-05a1-sdcp-v2.patch` | 소스 트리 기준 최종 패치 (`git format-patch`) |
| `libfprint_egismoc_full_fix.patch` | v2 패치 (위와 같은 변경) |
| `libfprint_egismoc_sdcp_reboot_fix.patch` / `.md` | 재부팅 수정 패치와 설명 |
| `libfprint_egismoc_assert_fix.patch` | `task_ssm` assert 수정 패치 |
| `usable_SDCP_versions_README.md` | v1 / v2 차이 정리 |
| `configs/libfprint/libfprint-2.so.2.0.0` | v2 빌드 바이너리 |
| `configs/pam/fprintd` | PAM 프로필 (`max-tries=3 timeout=30`) |
| `fingerprint_setup.sh` (+ `_README.md`) | 패치 라이브러리 + PAM 설치 / `--restore`로 순정 복원 |
| `pam_fprint_tuning.sh` (+ `_README.md`) | PAM 옵션만 적용 |
| `scripts/` | 위 스크립트가 호출하는 하위 스크립트 |
| `archive/agy-workdir/` | agy 작업 당시 노트와 패치 (`error_progress.md`, v1 패치 등) |
| `src/` (git 제외) | 로컬 소스 트리. `libfprint-egismoc-sdcp` (브랜치 `gb4p-05a1-sdcp-v2`), `libfprint-egismoc-sdcp-fix` |

## 사용

설치:

```bash
sudo ./fingerprint_setup.sh
```

순정 libfprint로 복원 (패치 라이브러리 제거, `libfprint-2-2` hold 해제):

```bash
sudo ./fingerprint_setup.sh --restore
```

## 소스에서 다시 빌드

`src/libfprint-egismoc-sdcp`는 폴더를 옮겼기 때문에 기존 `builddir`의 절대 경로가 맞지 않습니다. 새로 설정하세요:

```bash
cd src/libfprint-egismoc-sdcp
meson setup --wipe builddir -Ddrivers=egismoc -Ddoc=false -Dgtk-examples=false
ninja -C builddir
```

링크 단계에서 OpenSSL 심볼 오류가 나면 `meson.build`의 `driver_helper_mapping`에 `'egismoc' : [ 'openssl' ],`를 추가하세요 (antoskuu `install.sh`와 같은 처리). 폴더 이동 뒤 재빌드는 확인하지 않았습니다.

다른 곳에서 받을 때:

```bash
git clone https://github.com/TenSeventy7/libfprint-egismoc-sdcp.git
cd libfprint-egismoc-sdcp && git checkout 4d128d4
git am /path/to/gb4p-05a1-sdcp-v2.patch
```
