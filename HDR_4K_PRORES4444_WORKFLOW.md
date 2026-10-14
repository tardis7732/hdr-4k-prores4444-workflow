# 다른 컴퓨터에서 실행하는 SDR → HDR → 4K HDR → ProRes 4444

이 가이드는 1920×1080, 24fps SDR 입력을 HDR로 생성하고 3840×2160 HDR로 업스케일한 뒤, **Nuke Apple ProRes 4444 12-bit / ACEScct MOV**로 출력하는 절차다. 톤매핑·디스플레이 LUT는 적용하지 않는다. 현재 작업 폴더·서버·세션 인증을 참조하지 않는다.

아래 코드와 API JSON을 표시된 이름으로 저장하여 실행한다. 모델·처리 그래프는 실제 사용한 설정이다. 이식용 로더 및 예제 코드는 새 컴퓨터에서 전체 실행 검증이 필요하다.

## 1. 설치

필요 환경: CUDA 지원 NVIDIA GPU, CUDA 지원 PyTorch, Python 3.12, Git, FFmpeg/FFprobe, ComfyUI, ComfyUI-LTXVideo HDR 노드, Nuke 17.1v1 및 유효한 라이선스.

실제 BF16 모델·float32 VAE·4K 타일 설정은 H200 141GB급 GPU에서 실행했다. 작은 GPU에서도 같은 설정으로 실행된다고 보장하지 않는다. [공식 설치 안내](https://github.com/Lightricks/ComfyUI-LTXVideo#prerequisites)를 참고한다.

재현 기준 커밋:

| 코드 | 커밋 |
| --- | --- |
| ComfyUI | `1af040bf022569d7a890241c8dd79b296cda483f` |
| ComfyUI-LTXVideo | `3bf3ca62595f1764c47d01c35c8e5dfe47e1a88f` |

ComfyUI 환경을 만들고 GPU에 맞는 PyTorch를 설치한 뒤, ComfyUI 최상위 디렉터리에서 실행한다.

```bash
git checkout 1af040bf022569d7a890241c8dd79b296cda483f
git clone https://github.com/Lightricks/ComfyUI-LTXVideo.git custom_nodes/ComfyUI-LTXVideo
git -C custom_nodes/ComfyUI-LTXVideo checkout 3bf3ca62595f1764c47d01c35c8e5dfe47e1a88f
python -m pip install -r requirements.txt
python -m pip install -r custom_nodes/ComfyUI-LTXVideo/requirements.txt
python -m pip install OpenImageIO OpenEXR colour-science requests
```

`import colour; print(colour.RGB_COLOURSPACES['ACEScg'])`와 `import OpenImageIO`가 성공해야 한다. 설치할 패키지는 **colour-science**다. 다른 환경의 절대 PYTHONPATH를 가져오지 않고 사용할 환경에 설치한다.

## 2. 모델

| 저장소 | revision |
| --- | --- |
| [LTX-2.5](https://huggingface.co/Lightricks/LTX-2.5) | `49b093a39c19169a8a81721dcc541e07e945232f` |
| [SDR-To-HDR](https://huggingface.co/Lightricks/LTX-2.5-22b-IC-LoRA-SDR-To-HDR) | `c7578ebddb54f4210e534e4d8cad698a5a520692` |
| [Refine-Details](https://huggingface.co/Lightricks/LTX-2.5-22b-IC-LoRA-Refine-Details) | `4912c478b35dd96b6cdcc5f7c7ff9d72c2c57929` |

모델 종류에 맞는 ComfyUI 검색 경로에 등록한다.

```text
diffusion_models: ltx-2.5-22b-distilled-transformer-bf16.safetensors
vae: ltx-2.5-video-vae-bf16.safetensors
vae: ltx-2.5-audio-vae-bf16.safetensors
text_encoders: gemma4-12b-with-proj-ltx-2.5-bf16.safetensors
latent_upscale_models: ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors
loras: ltx-2.5-22b-ic-lora-sdr-to-hdr-1.0.safetensors
loras: ltx-2.5-22b-ic-lora-refine-details-1.0.safetensors
```

`ltx-2.5-22b-ic-lora-sdr-to-hdr-scene-emb.safetensors`도 준비하여 `LTXVLoadConditioning`의 file_name 목록에 등록한다. 정확한 검색 경로는 설치한 노드 버전에서 확인한다. 모델명이 선택 목록에 나타나는지 먼저 확인한다.

## 3. 추가 노드와 엔진

부록의 `portable_hdr_nodes.py`를 ComfyUI custom_nodes에 저장하고 재시작한다. RGB16 입력 로더와 HDR float Lanczos 리사이즈가 포함되어 있다.

```bash
python main.py --listen 127.0.0.1 --port 8188 --disable-auto-launch
```

`PortableRGB16Loader`, `LTXTaskFloatHDRResize`, `LTXICLoRALoaderModelOnly`, `LTXVLoadConditioning`, `LTXVVAEForceFloat32`, `LTXVHDRDecodePostprocess`, `LTXVLoadEXRSequence`, `LTXVTiledFusionSampler`가 등록되어 있어야 한다.

## 4. 입력 준비

실제 프레임 수 N에 대해 모델 입력 M은 `((N-1+7)//8)*8+1`이다. N=23이면 M=25, N=67이면 M=73. 마지막 프레임을 복제하여 M으로 맞추고 최종 결과는 N으로 자른다.

```bash
ffprobe -v error -count_frames -select_streams v:0 -show_streams -of json input.mp4
```

23프레임 입력 예:

```bash
ffmpeg -i input.mp4 -vf "format=gbrp16le,pad=1920:1088:0:4:black,tpad=stop_mode=clone:stop=2" -frames:v 25 -an -c:v ffv1 -level 3 -coder 1 -context 1 -pix_fmt gbrp16le -color_range pc -colorspace rgb -color_primaries bt709 -color_trc bt709 prepared.mkv
```

위 예는 원본의 자동 색 해석을 사용한다. 태그가 없거나 잘못되면 실제 원본의 matrix/range를 확인해 명시한다. RGB16 준비는 8-bit 원본의 정보를 늘리는 것이 아니라 추가 양자화를 피하는 과정이다.

## 5. HDR 생성과 4K HDR

부록의 native.json과 hdr4k.json을 저장한다. 이 JSON은 ComfyUI UI 저장 형식이 아니라 API prompt 형식이다.

| 항목 | 설정 |
| --- | --- |
| Seed | 예제 123 |
| Native HDR | SDR-to-HDR LoRA + scene embedding, Euler 8 steps, CFG 1 |
| Native decode | float32 VAE, tile 512 / overlap 64 / temporal 128 / overlap 32 |
| HDR 4K | HDR refinement 8 steps → latent spatial ×2 → refinement 3 steps |
| Fusion | tile 1024×576, overlap 0.5, blend variance 0.05, grid cycle 1, tile frames 97 |
| 4K decode | float32 VAE, tile 768 / overlap 192 / temporal 128 / overlap 32 |
| Exposure / EXR | 0.0 / scene-linear ACEScg half-float |

시드를 바꿀 때 두 JSON의 모든 seed/noise_seed 입력을 변경하고 새 출력 위치를 사용한다. 이전 HDR 결과나 prompt history를 재사용하지 않는다.

native.json에서 다음을 변경한다.

- `INPUT_RGB16_MKV`: prepared.mkv 절대 경로.
- `NATIVE_MODEL_EXR_DIR`: 새로운 모델 출력 EXR 절대 경로.
- 노드 8 frame_load_cap, 노드 9 length, 노드 12 frames_number: M.

부록 submit.py로 `python submit.py native.json`을 실행한다. 성공 후 모델 EXR을 crop_exr.py로 자른다. 23프레임 예:

```bash
python crop_exr.py native_model_exr hdr_exr --frames 23 --width 1920 --height 1080 --top 4 --guide hdr_guide --model-frames 25
```

hdr4k.json에서 다음을 변경한다.

- `PADDED_HDR_GUIDE_DIR`: 위 hdr_guide 절대 경로.
- `UHD_MODEL_EXR_DIR`: 새로운 4K 모델 출력 EXR 절대 경로.
- 노드 2 frame_cap, 노드 11 length: M.

```bash
python submit.py hdr4k.json
python crop_exr.py uhd_model_exr hdr4k_exr --frames 23 --width 3840 --height 2160 --top 8
```

이 예제는 한 청크의 짧은 1080p/24fps 입력을 처리한다. 긴 영상은 121프레임 청크·112프레임 간격·9프레임 overlap 및 ACEScg 선형 블렌딩 조립이 추가로 필요하다. 다른 fps나 종횡비는 conditioning·크기·패딩도 함께 변경해야 한다.

## 6. Nuke 12-bit MOV

부록 nuke_export.py를 저장한다. spec.json 예:

```json
{"sequence":"ABSOLUTE_HDR_EXR_DIR","output":"ABSOLUTE_VIDEO_ONLY_MOV","frames":23,"width":3840,"height":2160,"fps":24}
```

PowerShell 실행 예:

```powershell
$env:HDR_EXPORT_SPEC = (Resolve-Path spec.json).Path
& 'C:\Program Files\Nuke17.1v1\Nuke17.1.exe' --safe -t -i -n -m 8 nuke_export.py
```

Nuke의 Apple writer와 **ProRes 4:4:4:4 12-bit** 프로파일을 선택한다. Read는 ACEScg, Write는 ACEScct, Raw off, Rec 709 YCbCr matrix다. 디스플레이 변환·톤매핑을 넣지 않는다. FFmpeg prores_ks profile 4로 대체하면 같은 입력 정밀도가 아니다.

Nuke가 생성한 영상 전용 MOV를 부록 tag_prores.py로 복사·태그 정리 후 원본 오디오를 copy mux한다.

```bash
python tag_prores.py video_only.mov video_tagged.mov
ffmpeg -i video_tagged.mov -i input.mp4 -map 0:v:0 -map 1:a? -map_metadata 0 -c copy -color_primaries 2 -color_trc 2 -colorspace bt709 -movflags +faststart+write_colr+use_metadata_tags output_ACEScct_ProRes4444.mov
```

태그는 primaries/transfer unspecified, coding matrix BT.709로 맞춘다. 로그 RGB를 Rec.709 RGB로 변환하는 것이 아니다.

1080p HDR MOV는 spec의 sequence를 hdr_exr, width/height를 1920/1080으로 바꿔 별도 출력한다. 4K MOV의 축소본으로 대신하지 않는다.

## 7. 검증과 읽기

```bash
ffprobe -v error -count_frames -show_streams -of json output_ACEScct_ProRes4444.mov
```

확인: profile 4444, codec tag ap4h, decoder pixel format yuv444p12le, 실제 프레임 수 N, 24fps, 해상도, Video Range, bt709 coding matrix, primaries/transfer unspecified. Nuke 렌더 로그의 실제 12-bit Write 프로파일도 확인한다. 디코더 포맷만으로 입력 정밀도를 판정하지 않는다.

원본과 MOV 오디오 스트림 해시가 같아야 한다. 오디오 없는 원본은 비교를 생략한다.

```bash
ffmpeg -v error -i input.mp4 -map 0:a:0 -c copy -f hash -hash sha256 -
ffmpeg -v error -i output_ACEScct_ProRes4444.mov -map 0:a:0 -c copy -f hash -hash sha256 -
```

Nuke Read: **ACEScct, Raw off, Rec 709 matrix, Video Range**, Root working ACEScg. RGB 색공간을 Rec.709로 지정하지 않는다. HDR의 1 초과 밝기는 ACEScg로 풀어 선형 픽셀 값에서 확인한다. 동일 프레임의 EXR과 MOV를 같은 ACEScg 공간에서 비교하고, EXR 전체 프레임의 finite RGB 및 파일 해시를 확인한다.

## 부록: 코드 및 전체 API 그래프

아래 그래프의 기본값은 시드 123, M=25다. 경로·프레임 수를 앞의 설명에 맞춰 바꾼다.

### portable_hdr_nodes.py

```python
import json,subprocess
import numpy as np
import torch

class PortableRGB16Loader:
    @classmethod
    def INPUT_TYPES(cls):
        return {'required':{'video':('STRING',),'force_rate':('INT',{'default':0}),'custom_width':('INT',{'default':0}),'custom_height':('INT',{'default':0}),'frame_load_cap':('INT',{'default':25,'min':1}),'start_time':('FLOAT',{'default':0.0}),'format':('STRING',{'default':'None'})}}
    RETURN_TYPES=('IMAGE',)
    FUNCTION='load'
    CATEGORY='Portable HDR'
    def load(self,video,force_rate,custom_width,custom_height,frame_load_cap,start_time,format):
        assert force_rate==custom_width==custom_height==0 and start_time==0
        info=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_streams','-of','json',video]))['streams'][0]
        w,h=info['width'],info['height']
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',video,'-frames:v',str(frame_load_cap),'-an','-pix_fmt','rgb48le','-f','rawvideo','pipe:1'])
        assert len(raw)==frame_load_cap*w*h*6
        pixels=np.frombuffer(raw,dtype='<u2').reshape(frame_load_cap,h,w,3).astype(np.float32)/65535.0
        return (torch.from_numpy(pixels),)

import numpy as np
import OpenImageIO as oiio
import torch

class LTXTaskFloatHDRResize:
    @classmethod
    def INPUT_TYPES(cls):
        return {'required':{'image':('IMAGE',),'width':('INT',{'default':1920,'min':1,'max':8192}),'height':('INT',{'default':1088,'min':1,'max':8192}),'reflect_pad_height':('INT',{'default':0,'min':0,'max':8192})}}
    RETURN_TYPES=('IMAGE',)
    FUNCTION='resize'
    CATEGORY='LTX task/HDR'

    def resize(self,image,width,height,reflect_pad_height=0):
        source=image.detach().float().cpu().numpy()
        result=np.empty((len(source),height,width,source.shape[-1]),dtype=np.float32)
        for idx,frame in enumerate(source):
            if reflect_pad_height>frame.shape[0]:
                padding=reflect_pad_height-frame.shape[0]
                frame=np.pad(frame,((padding//2,padding-padding//2),(0,0),(0,0)),mode='reflect')
            if frame.shape[:2]==(height,width):
                result[idx]=frame
            else:
                buf=oiio.ImageBuf(np.ascontiguousarray(frame))
                resized=oiio.ImageBufAlgo.resize(buf,filtername='lanczos3',roi=oiio.ROI(0,width,0,height,0,1,0,frame.shape[-1]))
                if resized.has_error:raise RuntimeError(resized.geterror())
                result[idx]=resized.get_pixels(oiio.FLOAT)
        if not np.isfinite(result).all():raise ValueError('Non-finite HDR guide after float Lanczos resize')
        print('FLOAT_HDR_RESIZE',source.shape,'->',result.shape,'range',float(result.min()),float(result.max()),flush=True)
        return (torch.from_numpy(result).to(image.device),)

NODE_CLASS_MAPPINGS={'LTXTaskFloatHDRResize':LTXTaskFloatHDRResize,'PortableRGB16Loader':PortableRGB16Loader}
```

### submit.py

```python
import json,sys,time,requests
base='http://127.0.0.1:8188'
with open(sys.argv[1],encoding='utf-8') as f:graph=json.load(f)
r=requests.post(base+'/prompt',json={'prompt':graph},timeout=120)
r.raise_for_status();result=r.json()
if result.get('node_errors'):raise RuntimeError(result['node_errors'])
pid=result['prompt_id'];print('submitted',pid,flush=True)
while True:
    h=requests.get(base+'/history/'+pid,timeout=120).json().get(pid)
    if h:
        assert h['status']['status_str']=='success',h['status']
        print('completed',pid);break
    time.sleep(5)
```

### crop_exr.py

```python
import argparse,shutil
from pathlib import Path
import numpy as np
import OpenEXR
p=argparse.ArgumentParser()
p.add_argument('source');p.add_argument('dest')
for k in ['frames','width','height','top']:p.add_argument('--'+k,type=int,required=True)
p.add_argument('--guide');p.add_argument('--model-frames',type=int)
a=p.parse_args();dst=Path(a.dest);dst.mkdir(parents=True,exist_ok=True)
files=sorted(Path(a.source).glob('*.exr'));assert len(files)>=a.frames
for i,f in enumerate(files[:a.frames]):
    with OpenEXR.File(str(f)) as e:
        rgb=e.channels()['RGB'].pixels
        rgb=np.ascontiguousarray(rgb[a.top:a.top+a.height,:a.width,:3],dtype=np.float16)
        assert rgb.shape==(a.height,a.width,3) and np.isfinite(rgb).all()
        header=dict(e.header())
        for k in ['dataWindow','displayWindow','channels']:header.pop(k,None)
        header.update(type=OpenEXR.scanlineimage,compression=OpenEXR.ZIP_COMPRESSION,colorSpace='ACEScg')
        out=dst/f'frame_{i:06d}.exr';assert not out.exists(),out
        OpenEXR.File(header,{'RGB':rgb}).write(str(out))
if a.guide:
    assert a.model_frames>=a.frames
    guide=Path(a.guide);guide.mkdir(parents=True,exist_ok=True)
    for i in range(a.model_frames):
        out=guide/f'frame_{i:06d}.exr';assert not out.exists(),out
        shutil.copyfile(dst/f'frame_{min(i,a.frames-1):06d}.exr',out)
```

### nuke_export.py

```python
"""Empty-memory Nuke Apple ProRes 4444 12-bit render; never opens an NK."""
import json
import os
from pathlib import Path
import time
import nuke

spec=json.loads(Path(os.environ['HDR_EXPORT_SPEC']).read_text(encoding='utf-8'))
spec['video']=spec['output']
assert spec.get('fps',24)==24
assert not nuke.allNodes()
root=nuke.root()
root['colorManagement'].setValue('OCIO')
root['OCIO_config'].setValue('fn-nuke_cg-config-v2.2.0_aces-v1.3_ocio-v2.4')
root['workingSpaceLUT'].setValue('ACEScg')
root['fps'].setValue(24)
root['first_frame'].setValue(1)
root['last_frame'].setValue(spec['frames'])
root['format'].setValue(nuke.addFormat(f"{spec['width']} {spec['height']} 1 ProRes_{spec['width']}x{spec['height']}"))
reader=nuke.nodes.Read(file=(Path(spec['sequence'])/'frame_%06d.exr').as_posix())
for key in ['first','origfirst']: reader[key].setValue(0)
for key in ['last','origlast']: reader[key].setValue(spec['frames']-1)
reader['frame_mode'].setValue('offset')
reader['frame'].setValue('-1')
reader['colorspace'].setValue('ACEScg')
reader['raw'].setValue(False)
writer=nuke.nodes.Write(file=Path(spec['video']).as_posix(),file_type='mov',inputs=[reader])
writer['channels'].setValue('rgb')
writer['mov64_codec'].setValue('appr')
writer['mov_prores_codec_profile'].setValue('ProRes 4:4:4:4 12-bit')
writer['mov64_ycbcr_matrix_type'].setValue('Rec 709')
writer['mov64_color_primaries'].setValue('Unspecified')
writer['mov64_transfer_function'].setValue('Unspecified')
writer['mov64_fps'].setValue(24)
writer['mov64_fast_start'].setValue(True)
writer['colorspace'].setValue('ACEScct')
writer['raw'].setValue(False)
nuke.execute(writer,1,spec['frames'])
print('APPLE_PRORES4444_12BIT_RENDER_COMPLETE',spec['video'])
```

### tag_prores.py

```python
import json,shutil,subprocess,sys
from pathlib import Path
src,dst=sys.argv[1:]
assert Path(src).resolve()!=Path(dst).resolve() and not Path(dst).exists()
shutil.copyfile(src,dst)
packets=json.loads(subprocess.check_output(['ffprobe','-v','error','-select_streams','v:0','-show_packets','-show_entries','packet=pos','-of','json',dst]))['packets']
with open(dst,'r+b') as f:
    for p in packets:
        pos=int(p['pos']);f.seek(pos);h=f.read(28)
        assert h[4:8]==b'icpf' and int.from_bytes(h[8:10],'big')>=28
        f.seek(pos+22);f.write(bytes([2,2,1]))
```

### native.json

```json
{
  "1": {
    "class_type": "UNETLoader",
    "inputs": {
      "unet_name": "ltx-2.5-22b-distilled-transformer-bf16.safetensors",
      "weight_dtype": "default"
    }
  },
  "2": {
    "class_type": "LTXICLoRALoaderModelOnly",
    "inputs": {
      "model": [
        "1",
        0
      ],
      "lora_name": "ltx-2.5-22b-ic-lora-sdr-to-hdr-1.0.safetensors",
      "strength_model": 1.0
    }
  },
  "3": {
    "class_type": "LTXVLoadConditioning",
    "inputs": {
      "file_name": "ltx-2.5-22b-ic-lora-sdr-to-hdr-scene-emb.safetensors",
      "device": "cpu"
    }
  },
  "5": {
    "class_type": "LTXVConditioning",
    "inputs": {
      "positive": [
        "3",
        0
      ],
      "negative": [
        "3",
        0
      ],
      "frame_rate": 24.0
    }
  },
  "6": {
    "class_type": "VAELoader",
    "inputs": {
      "vae_name": "ltx-2.5-video-vae-bf16.safetensors"
    }
  },
  "7": {
    "class_type": "VAELoader",
    "inputs": {
      "vae_name": "ltx-2.5-audio-vae-bf16.safetensors"
    }
  },
  "8": {
    "class_type": "PortableRGB16Loader",
    "inputs": {
      "video": "INPUT_RGB16_MKV",
      "force_rate": 0,
      "custom_width": 0,
      "custom_height": 0,
      "frame_load_cap": 25,
      "start_time": 0,
      "format": "None"
    }
  },
  "9": {
    "class_type": "EmptyLTXVLatentVideo",
    "inputs": {
      "width": 1920,
      "height": 1088,
      "length": 25,
      "batch_size": 1
    }
  },
  "30": {
    "class_type": "LTXVSDRToHDRWorkingSpace",
    "inputs": {
      "image": [
        "8",
        0
      ],
      "color_space": "srgb_gamma"
    }
  },
  "31": {
    "class_type": "LTXVVAEForceFloat32",
    "inputs": {
      "vae": [
        "6",
        0
      ]
    }
  },
  "32": {
    "class_type": "EmptyImage",
    "inputs": {
      "width": 64,
      "height": 9,
      "batch_size": 57,
      "color": 0
    }
  },
  "33": {
    "class_type": "LTXVImgToVideoInplace",
    "inputs": {
      "vae": [
        "31",
        0
      ],
      "image": [
        "32",
        0
      ],
      "latent": [
        "9",
        0
      ],
      "strength": 0.7,
      "bypass": true
    }
  },
  "10": {
    "class_type": "LTXAddVideoICLoRAGuide",
    "inputs": {
      "positive": [
        "5",
        0
      ],
      "negative": [
        "5",
        1
      ],
      "vae": [
        "31",
        0
      ],
      "latent": [
        "33",
        0
      ],
      "image": [
        "30",
        0
      ],
      "frame_idx": 0,
      "strength": 1.0,
      "latent_downscale_factor": [
        "2",
        1
      ],
      "crop": "disabled",
      "use_tiled_encode": false,
      "tile_size": 256,
      "tile_overlap": 64
    }
  },
  "12": {
    "class_type": "LTXVEmptyLatentAudio",
    "inputs": {
      "audio_vae": [
        "7",
        0
      ],
      "frames_number": 25,
      "frame_rate": 24.0,
      "batch_size": 1
    }
  },
  "14": {
    "class_type": "LTXVConcatAVLatent",
    "inputs": {
      "video_latent": [
        "10",
        2
      ],
      "audio_latent": [
        "12",
        0
      ]
    }
  },
  "15": {
    "class_type": "CFGGuider",
    "inputs": {
      "model": [
        "2",
        0
      ],
      "positive": [
        "10",
        0
      ],
      "negative": [
        "10",
        1
      ],
      "cfg": 1.0
    }
  },
  "16": {
    "class_type": "RandomNoise",
    "inputs": {
      "noise_seed": 123
    }
  },
  "17": {
    "class_type": "KSamplerSelect",
    "inputs": {
      "sampler_name": "euler"
    }
  },
  "18": {
    "class_type": "ManualSigmas",
    "inputs": {
      "sigmas": "1.0, 0.99375, 0.9875, 0.98125, 0.975, 0.909375, 0.725, 0.421875, 0.0"
    }
  },
  "19": {
    "class_type": "SamplerCustomAdvanced",
    "inputs": {
      "noise": [
        "16",
        0
      ],
      "guider": [
        "15",
        0
      ],
      "sampler": [
        "17",
        0
      ],
      "sigmas": [
        "18",
        0
      ],
      "latent_image": [
        "14",
        0
      ]
    }
  },
  "20": {
    "class_type": "LTXVSeparateAVLatent",
    "inputs": {
      "av_latent": [
        "19",
        0
      ]
    }
  },
  "21": {
    "class_type": "LTXVCropGuides",
    "inputs": {
      "positive": [
        "10",
        0
      ],
      "negative": [
        "10",
        1
      ],
      "latent": [
        "20",
        0
      ]
    }
  },
  "22": {
    "class_type": "VAEDecodeTiled",
    "inputs": {
      "samples": [
        "21",
        2
      ],
      "vae": [
        "31",
        0
      ],
      "tile_size": 512,
      "overlap": 64,
      "temporal_size": 128,
      "temporal_overlap": 32
    }
  },
  "23": {
    "class_type": "LTXVHDRDecodePostprocess",
    "inputs": {
      "image": [
        "22",
        0
      ],
      "transfer": "acescct",
      "exposure": 0.0,
      "save_exr": true,
      "exr_color_space": "acescg",
      "output_dir": "NATIVE_MODEL_EXR_DIR",
      "filename_prefix": "frame",
      "half_precision": true
    }
  }
}
```

### hdr4k.json

```json
{
  "1": {
    "class_type": "VAELoader",
    "inputs": {
      "vae_name": "ltx-2.5-video-vae-bf16.safetensors"
    }
  },
  "30": {
    "class_type": "LTXVVAEForceFloat32",
    "inputs": {
      "vae": [
        "1",
        0
      ]
    }
  },
  "2": {
    "class_type": "LTXVLoadEXRSequence",
    "inputs": {
      "path": "PADDED_HDR_GUIDE_DIR",
      "color_space": "acescg",
      "frame_rate": 24,
      "frame_start": 0,
      "frame_cap": 25,
      "trim_to_8k1": true
    }
  },
  "3": {
    "class_type": "UNETLoader",
    "inputs": {
      "unet_name": "ltx-2.5-22b-distilled-transformer-bf16.safetensors",
      "weight_dtype": "default"
    }
  },
  "4": {
    "class_type": "LTXICLoRALoaderModelOnly",
    "inputs": {
      "model": [
        "3",
        0
      ],
      "lora_name": "ltx-2.5-22b-ic-lora-refine-details-1.0.safetensors",
      "strength_model": 1.0
    }
  },
  "5": {
    "class_type": "CLIPLoader",
    "inputs": {
      "clip_name": "gemma4-12b-with-proj-ltx-2.5-bf16.safetensors",
      "type": "ltxv",
      "device": "default"
    }
  },
  "8": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "clip": [
        "5",
        0
      ],
      "text": ""
    }
  },
  "9": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "clip": [
        "5",
        0
      ],
      "text": ""
    }
  },
  "10": {
    "class_type": "LTXVConditioning",
    "inputs": {
      "positive": [
        "8",
        0
      ],
      "negative": [
        "9",
        0
      ],
      "frame_rate": 24
    }
  },
  "11": {
    "class_type": "EmptyLTXVLatentVideo",
    "inputs": {
      "width": 1920,
      "height": 1088,
      "length": 25,
      "batch_size": 1
    }
  },
  "12": {
    "class_type": "LTXTaskFloatHDRResize",
    "inputs": {
      "image": [
        "2",
        0
      ],
      "width": 1920,
      "height": 1088,
      "reflect_pad_height": 1088
    }
  },
  "13": {
    "class_type": "LTXAddVideoICLoRAGuide",
    "inputs": {
      "positive": [
        "10",
        0
      ],
      "negative": [
        "10",
        1
      ],
      "latent": [
        "11",
        0
      ],
      "image": [
        "12",
        0
      ],
      "frame_idx": 0,
      "strength": 1.0,
      "latent_downscale_factor": [
        "4",
        1
      ],
      "crop": "disabled",
      "use_tiled_encode": false,
      "tile_size": 256,
      "tile_overlap": 64,
      "use_streaming": true,
      "tile_frames": 97,
      "vae": [
        "30",
        0
      ]
    }
  },
  "14": {
    "class_type": "ManualSigmas",
    "inputs": {
      "sigmas": "1.0, 0.99375, 0.9875, 0.98125, 0.975, 0.909375, 0.725, 0.421875, 0.0"
    }
  },
  "15": {
    "class_type": "KSamplerSelect",
    "inputs": {
      "sampler_name": "euler"
    }
  },
  "16": {
    "class_type": "LTXVTiledFusionSampler",
    "inputs": {
      "positive": [
        "13",
        0
      ],
      "negative": [
        "13",
        1
      ],
      "latents": [
        "13",
        2
      ],
      "sigmas": [
        "14",
        0
      ],
      "model": [
        "4",
        0
      ],
      "sampler": [
        "15",
        0
      ],
      "seed": 123,
      "cfg": 1.0,
      "tile_width": 1024,
      "tile_height": 576,
      "overlap_frac": 0.5,
      "blend_var": 0.05,
      "grid_cycle": 1,
      "tile_frames": 97,
      "vae": [
        "30",
        0
      ],
      "canvas_device": "auto"
    }
  },
  "21": {
    "class_type": "LatentUpscaleModelLoader",
    "inputs": {
      "model_name": "ltx-2.5-latent-spatial-upscaler-x2-bf16-1.0.safetensors"
    }
  },
  "24": {
    "class_type": "LTXVLatentUpsampler",
    "inputs": {
      "samples": [
        "16",
        0
      ],
      "upscale_model": [
        "21",
        0
      ],
      "vae": [
        "30",
        0
      ]
    }
  },
  "22": {
    "class_type": "CLIPTextEncode",
    "inputs": {
      "clip": [
        "5",
        0
      ],
      "text": "The same scene, sharper and more detailed, fine textures, clean edges."
    }
  },
  "20": {
    "class_type": "LTXVConditioning",
    "inputs": {
      "positive": [
        "22",
        0
      ],
      "negative": [
        "9",
        0
      ],
      "frame_rate": 24
    }
  },
  "23": {
    "class_type": "LTXTaskFloatHDRResize",
    "inputs": {
      "image": [
        "12",
        0
      ],
      "width": 3840,
      "height": 2176,
      "reflect_pad_height": 0
    }
  },
  "25": {
    "class_type": "LTXAddVideoICLoRAGuide",
    "inputs": {
      "positive": [
        "20",
        0
      ],
      "negative": [
        "20",
        1
      ],
      "latent": [
        "24",
        0
      ],
      "image": [
        "23",
        0
      ],
      "frame_idx": 0,
      "strength": 1.0,
      "latent_downscale_factor": [
        "4",
        1
      ],
      "crop": "disabled",
      "use_tiled_encode": false,
      "tile_size": 256,
      "tile_overlap": 64,
      "use_streaming": true,
      "tile_frames": 97,
      "vae": [
        "30",
        0
      ]
    }
  },
  "27": {
    "class_type": "ManualSigmas",
    "inputs": {
      "sigmas": "0.909375, 0.725, 0.421875, 0.0"
    }
  },
  "26": {
    "class_type": "LTXVTiledFusionSampler",
    "inputs": {
      "positive": [
        "25",
        0
      ],
      "negative": [
        "25",
        1
      ],
      "latents": [
        "25",
        2
      ],
      "sigmas": [
        "27",
        0
      ],
      "model": [
        "4",
        0
      ],
      "sampler": [
        "15",
        0
      ],
      "seed": 123,
      "cfg": 1.0,
      "tile_width": 1024,
      "tile_height": 576,
      "overlap_frac": 0.5,
      "blend_var": 0.05,
      "grid_cycle": 1,
      "tile_frames": 97,
      "vae": [
        "30",
        0
      ],
      "canvas_device": "auto"
    }
  },
  "6": {
    "class_type": "VAEDecodeTiled",
    "inputs": {
      "samples": [
        "26",
        0
      ],
      "vae": [
        "30",
        0
      ],
      "tile_size": 768,
      "overlap": 192,
      "temporal_size": 128,
      "temporal_overlap": 32
    }
  },
  "7": {
    "class_type": "LTXVHDRDecodePostprocess",
    "inputs": {
      "image": [
        "6",
        0
      ],
      "transfer": "acescct",
      "exposure": 0.0,
      "save_exr": true,
      "exr_color_space": "acescg",
      "output_dir": "UHD_MODEL_EXR_DIR",
      "filename_prefix": "frame",
      "half_precision": true
    }
  }
}
```
