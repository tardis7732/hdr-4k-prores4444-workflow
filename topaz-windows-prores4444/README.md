# Topaz Video Windows ProRes 4444

Windows용 Topaz Video에 ProRes 4444 MOV 출력 항목을 추가합니다.

## 설치

1. 이 폴더를 다운로드합니다.
2. 관리자 권한 PowerShell에서 `./install.ps1`을 실행합니다.
3. 진행 중인 출력이 끝나면 Topaz Video를 재시작합니다.
4. Codec **ProRes**, Profile **4444**, Container **MOV**를 선택합니다.

## 설정

| 항목 | 값 |
| --- | --- |
| 인코더 | `prores_ks` |
| 프로파일 | `4` (4444) |
| 픽셀 포맷 | `yuv444p10le` (10-bit 4:4:4) |
| MOV 코덱 태그 | `ap4h` |
| 알파 | 없음 |

## 파일

- `prores-4444-entry.json`: 추가할 인코더 항목
- `video-encoders.json`: Topaz Video 1.7.1 전체 설정 사본
- `install.ps1`: 기존 설정을 백업하고 4444 항목을 추가·갱신하는 설치기

설치 위치: `C:\ProgramData\Topaz Labs LLC\Topaz Video\models\video-encoders.json`

다른 버전에도 기존 항목을 보존하려면 설치기를 사용하세요. 복원할 때는 Topaz를 종료하고 설치기가 만든 `.bak`을 원래 파일로 복사합니다.
