# 지문 인식(EgisTec 1c7a:05a1) 트러블슈팅 경과 보고서

## 개요
- **대상 장치**: Samsung Galaxy Book 4 Pro/Ultra (USB ID: `1c7a:05a1`, LighTuning Technology Inc. ETU905A80-E)
- **베이스 프로젝트**: [TenSeventy7의 libfprint-egismoc-sdcp](https://github.com/TenSeventy7/libfprint/tree/egismoc-sdcp)
- **현재 증상 요약**:
  - `fprintd-enroll`을 통한 지문 등록은 완료되나, 직후 `fprintd-verify`를 통한 인증이 즉시 실패(또는 매치 안 됨)하고 기기 내부에 저장되었던 지문 데이터가 바로 삭제되는 문제 발생.

## 지금까지의 진행 상황 및 원인 분석

### 1. `fprintd-verify` 즉시 강제 종료 (수정 완료됨 -> 롤백)
- **증상**: 처음에 `fprintd-verify`를 실행하면 센서를 터치하기도 전에 즉시 `verify-no-match` (또는 abort)를 반환하고 종료됨.
- **원인**: `cmd_list`로 지문 개수를 조회할 때 기기가 0개를 반환하여 `fprintd-verify`가 `FP_DEVICE_ERROR_DATA_NOT_FOUND` 에러와 함께 비정상 종료됨. 즉, 등록 단계(`enroll`)에서 지문이 기기 내부 저장소에 정상적으로 커밋(Commit)되지 않았음.

### 2. 하드웨어 `65 E0` 에러 (수정 완료됨 -> 롤백)
- **증상**: 로그 분석 결과, `enroll` 마지막 단계의 `cmd_new_print_prefix` (지문 저장 명령)에 대해 기기가 `65 E0` 에러 코드를 반환하고 있었음.
- **원인 및 조치**: 
  1. **유령 터치(Ghost Touch) 문제**: 첫 번째 `enroll` 단계에서 센서를 만지지 않았음에도 통과되는 현상 발견. 원인은 이전에 발생했던 인터럽트 신호(`90 00 90 00`)가 USB 버퍼에 남아 있다가 즉시 읽혀 빈(Blank) 이미지를 캡처하게 만든 것. (100ms 타임아웃을 두어 잔류 패킷을 무시하도록 패치하여 해결)
  2. **Acer 전용 커맨드 충돌**: SDCP 포크 작성자(TenSeventy7)가 Acer(`0583`) 기기를 위해 캡처 직후 센서를 리셋하는 `cmd_capture_post_wait_finger`(`50 7a`) 커맨드를 추가했으나, 이것이 삼성(`05a1`) 기기에서는 버퍼를 초기화시켜 모든 캡처 이미지를 텅 비게 만들었을 가능성 확인. (해당 커맨드를 `05a1`에서는 건너뛰도록 패치)
- **결과**: 위 패치들을 통해 `fprintd-enroll`이 실제 손가락 터치를 정상적으로 10회 기다리게 되었고, `verify` 역시 손가락 터치를 기다리게끔 개선되었음.

### 3. 미해결 과제: Verify 이후 지문 자동 삭제 현상
- **증상**: `verify`에서 터치를 기다리게 만드는 데는 성공했으나, 여전히 `verify-no-match`가 뜨며, 직후에 지문이 기기에서 삭제됨 (`NoEnrolledPrints` 에러 발생).
- **의심되는 원인**: 
  - **SDCP HMAC 해시 생성 규격 문제**: `fpi_sdcp_generate_enrollment_id` 함수 등에서 HMAC 서명을 생성할 때 `sizeof("enroll")`를 사용하여 `\0` (널 종료 문자)까지 해시 계산에 포함하고 있음. 기기 펌웨어가 이 널 문자를 기대하지 않는다면 `Enrollment ID` 불일치나 무결성 에러로 간주하여 지문을 내부적으로 폐기(Invalidate)할 수 있음.
  - **05a1 전용 프로토콜 미세 차이**: `cmd_new_print_prefix` 커맨드 바이트 등에서 삼성 기기만의 TYPE2 전용 바이트(`0x80` 등)가 더 필요할 가능성 존재.

## 롤백 상태 기록 (2026-09-19)
세션이 길어짐에 따라, 원점에서의 재분석을 위해 현재 적용했던 **모든 커스텀 패치를 삭제**하고 깃허브(TenSeventy7)에서 받은 초기 상태로 리포지토리를 **완전 롤백(`git reset --hard`, `git clean -fd`) 및 재빌드**해 두었습니다.

- **작업 디렉토리**: `/home/hajun/.gemini/antigravity/scratch/libfprint-egismoc-sdcp/`
- **상태**: 순정(Original) TenSeventy7 `egismoc-sdcp` 브랜치 소스코드로 복구됨.

---
**다음 세션에서의 권장 진행 방향:**
1. 롤백된 순정 상태에서 SDCP 관련 HMAC 생성 로직(`sizeof` -> `strlen`)에 대한 검증.
2. Windows 환경에서 `05a1`의 정확한 `EnrollCommit` 및 `Identify` 단계의 SDCP 페이로드 분석을 통한 프로토콜 차이 확인.
