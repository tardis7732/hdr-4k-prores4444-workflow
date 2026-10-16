# Topaz Video Windows ProRes 4444

Windows용 **Topaz Video에 ProRes 4444 MOV 출력 항목을 추가**하는 설정과 설치기입니다.

설치 후 **Codec settings → ProRes → 4444 → MOV**를 선택해 출력할 수 있습니다.

[ZIP 다운로드](https://github.com/tardis7732/hdr-4k-prores4444-workflow/archive/refs/heads/main.zip) · [설정 파일 보기](topaz-windows-prores4444/prores-4444-entry.json) · [설치기 보기](topaz-windows-prores4444/install.ps1)

## 지원 환경

- Windows
- Topaz Video 설치 필요
- 설치 시 관리자 권한 필요
- 확인한 버전: **Topaz Video 1.7.1**

## 설치 방법

### 1. 다운로드하고 압축 풀기

위의 **ZIP 다운로드**를 누르거나 GitHub의 **Code → Download ZIP**을 선택합니다.

다운로드한 ZIP을 압축 해제하고 `topaz-windows-prores4444` 폴더를 확인합니다. 이 폴더의 `install.ps1`과 `prores-4444-entry.json`은 같은 위치에 두세요.

### 2. Topaz Video 종료

진행 중인 출력이 있으면 완료된 후 Topaz Video를 종료합니다.

### 3. 관리자 PowerShell에서 설치

시작 메뉴에서 **PowerShell**을 검색하고 **관리자 권한으로 실행**을 선택합니다.

다운로드 폴더에 기본 이름으로 압축을 풀었다면 아래 명령을 실행합니다.

```powershell
Set-Location -LiteralPath "$env:USERPROFILE\Downloads\hdr-4k-prores4444-workflow-main\topaz-windows-prores4444"
.\install.ps1
```

다른 위치에 압축을 풀었다면 첫 줄의 경로를 실제 `topaz-windows-prores4444` 폴더 위치로 바꿉니다.

설치 결과에 `"status": "installed"`, `"profile": "4444"`가 표시되면 완료입니다. 같은 폴더의 `install-result.json`에서도 설치 결과와 백업 경로를 확인할 수 있습니다.

### 4. 출력 항목 선택

Topaz Video를 다시 실행하고 영상을 불러온 뒤 **Codec settings**에서 다음과 같이 선택합니다.

| 항목 | 선택값 |
| --- | --- |
| Codec | **ProRes** |
| Profile | **4444** |
| Container | **MOV** |

모델과 출력 해상도를 설정한 후 **Export**를 실행합니다. 출력 해상도는 **Adjustments → Output resolution**에서 별도로 선택합니다.

## 적용되는 설정

| 항목 | 값 |
| --- | --- |
| 인코더 | `prores_ks` |
| 프로파일 | `4` — ProRes 4444 |
| 픽셀 포맷 | `yuv444p10le` — 10-bit 4:4:4 |
| MOV 코덱 태그 | `ap4h` |
| 알파 채널 | 없음 |
| 컨테이너 | `.mov` |

설치기는 기존 인코더 목록을 보존하면서 **4444 항목 하나만 추가하거나 갱신**합니다. 다시 실행해도 동일한 항목이 중복으로 추가되지 않습니다.

## 파일 안내

| 파일 | 용도 |
| --- | --- |
| [install.ps1](topaz-windows-prores4444/install.ps1) | 기존 설정을 백업하고 4444 항목을 적용하는 설치기 |
| [prores-4444-entry.json](topaz-windows-prores4444/prores-4444-entry.json) | 추가할 4444 인코더 항목 |
| [video-encoders.json](topaz-windows-prores4444/video-encoders.json) | Topaz Video 1.7.1 전체 설정에 4444 항목을 추가한 사본 |

다른 버전의 기존 항목을 보존하려면 **`install.ps1`을 사용**하세요.

기본 적용 파일은 다음과 같습니다.

```text
C:\ProgramData\Topaz Labs LLC\Topaz Video\models\video-encoders.json
```

## 백업 및 복원

설치할 때 기존 파일을 같은 폴더에 다음 이름으로 자동 백업합니다.

```text
video-encoders.json.backup-날짜-시간.bak
```

복원하려면 다음 순서로 진행합니다.

1. Topaz Video를 종료합니다.
2. `install-result.json`의 `backup` 경로에서 원하는 백업 파일을 확인합니다.
3. 관리자 권한으로 해당 백업을 원래 위치의 `video-encoders.json`에 덮어씁니다.
4. Topaz Video를 다시 실행합니다.

## 자주 확인할 사항

### 4444 항목이 보이지 않을 때

Topaz Video를 완전히 종료한 뒤 다시 실행합니다. 설치 결과가 `installed`인지 확인하고, **Codec을 ProRes로 선택한 다음 Profile 목록**을 확인하세요.

### 관리자 권한 오류가 나올 때

PowerShell을 **관리자 권한으로 실행**한 뒤 설치 명령을 다시 실행합니다.

### 파일을 찾을 수 없다고 나올 때

압축을 푼 위치와 PowerShell의 현재 경로를 확인하세요. `install.ps1`과 `prores-4444-entry.json`이 같은 폴더에 있어야 하며, 기본 적용 위치에 Topaz의 `video-encoders.json`이 있어야 합니다.

### Topaz 업데이트 후 항목이 사라졌을 때

`install.ps1`을 다시 실행하고 Topaz Video를 재시작합니다.
