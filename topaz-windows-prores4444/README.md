# Topaz Video Windows ProRes 4444 (Rec.709)

Topaz Video 1.7.1의 Windows 출력 목록에 `ProRes > 4444 Rec.709`를 추가합니다.

## 설정

- Encoder: `prores_ks`, profile `4`, MOV tag `ap4h`
- Encoder input: `yuv444p10le` (10-bit 4:4:4, alpha 없음)
- Color: BT.709 primaries / transfer / matrix, video/limited range
- MOV: `+faststart+write_colr`
- ProRes frame header: `prores_metadata` bitstream filter로 BT.709 명시
- Vendor: `Lavc` (실제 FFmpeg 인코더)

이 Topaz 빌드의 `prores_ks` 입력은 10-bit까지 지원합니다. FFprobe가 출력 디코드 형식을 `yuv444p12le`로 표시해도 네이티브 12-bit 입력 인코딩을 의미하지 않습니다. Nuke Apple ProRes 4444 12-bit 출력과 구분해야 합니다.

이 프로파일은 **올바르게 Rec.709 태그가 지정된 SDR 입력용**입니다. HDR/PQ/HLG/ACEScct를 Rec.709로 변환하지 않습니다. 입력 색상 태그가 없으면 JSON 출력 옵션만으로 MOV 색상 정보가 완전히 보정되지 않을 수 있습니다. 테스트는 입력 태그, MOV `colr`와 ProRes 프레임 헤더까지 확인했습니다.

## 설치

1. Topaz Video를 종료합니다.
2. 이 폴더를 로컬 디스크에 내려받습니다.
3. 관리자 권한 PowerShell에서 `./install.ps1`을 실행합니다.
4. Topaz를 다시 실행하고 Export의 ProRes 프로파일에서 **4444 Rec.709**를 선택합니다.

기본 대상:

`C:\ProgramData\Topaz Labs LLC\Topaz Video\models\video-encoders.json`

설치기는 기존 파일을 날짜가 붙은 `.bak`으로 보관하고, `prores-4444-rec709-win` 항목 하나만 추가하거나 갱신합니다. 다른 인코더 항목을 보존합니다. 앱 업데이트 후 항목이 사라지면 다시 설치할 수 있습니다.

- `prores-4444-rec709-entry.json`: 추가할 항목
- `video-encoders.json`: 1.7.1 기본 설정에 추가한 전체 JSON 사본
- `install.ps1`: 기존 인코더 목록을 보존하는 설치기
- `validation.json`: Topaz 번들 FFmpeg로 1080p / 24fps / 12프레임을 인코딩하고 검증한 기록

전체 JSON은 참고 사본입니다. 다른 Topaz 버전에서는 전체 파일 덮어쓰기보다 설치기로 항목만 추가하세요.

복원하려면 Topaz를 종료한 뒤 관리자 권한으로 설치기가 만든 `.bak`을 원래 `video-encoders.json`으로 복사합니다.

참고: [Topaz Custom Encoder Options](https://docs.topazlabs.com/topaz-video/advanced-functions/custom-encoder-options)
