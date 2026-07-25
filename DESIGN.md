<!-- SPARTA Content Lab 대시보드의 디자인 토큰 단일 원천(single source of truth). 목업(Planning/목업 샘플.png)에서 추출. 모든 화면 구현 세션은 이 토큰만 쓴다. -->
---
omd: 0.1
brand: SPARTA Content Lab
bootstrapped_from: Planning/목업 샘플.png
bootstrapped_at: 2026-07-22
stack: Ruby on Rails 8 + Tailwind CSS
---

# DESIGN.md — SPARTA Content Lab

## 0. 이 문서의 지위

이 문서는 확정 목업(`Planning/목업 샘플.png`)에서 **추출한** 디자인 토큰의 단일 원천이다. 새 디자인을 발명하지 않는다. 목업 재현이 목표이고, 목업에 없는 값(성과 배수 색 밴드, 정직성 상태, 다국어 대응)은 PRD(`_bmad-output/.../prd.md`)에서 파생했다.

이 대시보드는 화면 6개(대시보드 / 인기 콘텐츠 / 경쟁 채널 / 콘텐츠 갭 / 저장한 영상 / 설정)가 **서로 다른 세션에서 따로** 만들어진다. 각 세션이 목업의 파란색을 blue-600·blue-500·indigo-600으로 제각기 추정하면 화면이 어긋난다. 이 문서가 그 드리프트를 막는 유일한 장치다.

**규칙.** 여기 없는 색·간격·radius를 임의로 만들지 마라. 목업과 다르게 가고 싶으면 바꾸지 말고 운영자에게 물어라. 색상값은 목업에서 픽셀 샘플링한 실측치이며, 옆의 Tailwind 이름은 참고용 근사값이다(권위는 실측 hex에 있다).

---

## 1. Color

### 1.1 Primary — 브랜드 블루

목업의 좌측 내비 활성 pill, 추천 카드 번호 뱃지(1·2·3), 활성 기간 탭, 기회 점수 큰 숫자, 기본 버튼·링크가 전부 이 파랑이다. 실측 solid fill이 `#1145DD`로 일관됐다.

| 토큰 | Hex | 용도 | Tailwind 근사 |
|---|---|---|---|
| `primary-50` | `#EEF2FE` | 태그/칩 배경, 아주 옅은 강조면 | blue-50 |
| `primary-100` | `#DCE4FD` | hover 배경, 선택 배경 | blue-100 |
| `primary-500` | `#2E5BE6` | hover 상태의 primary | blue-500 |
| **`primary-600`** | **`#1145DD`** | **기본** — 내비 활성·번호 뱃지·활성 탭·기본 버튼·링크·기회 점수 | blue-700 근처 |
| `primary-700` | `#0E37B0` | pressed/active 상태 | blue-800 |

기회 점수 큰 숫자, 도넛 중앙 퍼센트, 스파크라인 라인 모두 `primary-600`을 쓴다.

### 1.2 Success — 그린

성과 배수 값, 구독자 증가율(+1.0%)에 쓰인다. 실측 `#159C49`.

| 토큰 | Hex | 용도 | Tailwind 근사 |
|---|---|---|---|
| `success-50` | `#E7F6EC` | 성공/양호 배경 tint | green-50 |
| `success-100` | `#C6EBD1` | 밴드 중간 tint | green-100 |
| **`success-600`** | **`#159C49`** | **기본** — 성과 배수·증가율 텍스트 | green-600 |
| `success-700` | `#0F7A38` | 진한 그린(높은 밴드) | green-700 |

### 1.3 Neutral — 텍스트·서피스·보더

목업은 흰색/근백색 캔버스 위에 얇은 회색 보더로 구조를 만든다(회색 배경면이 거의 없다). 카드 분리는 보더 + 아주 옅은 그림자로 한다.

| 토큰 | Hex | 용도 |
|---|---|---|
| `bg-app` | `#FBFCFD` | 페이지 캔버스(근백색) |
| `surface` | `#FFFFFF` | 카드·위젯·테이블 배경 |
| `surface-sunken` | `#F7F8FA` | 테이블 헤더 배경, 인풋 안쪽 |
| `border-default` | `#E5E7EB` | 카드·위젯·인풋 보더 (실측 #E2E6EB) |
| `border-subtle` | `#EEF1F5` | 테이블 행 구분선, 내부 divider |
| `text-strong` | `#111827` | 제목·헤딩·핵심 숫자 |
| `text-body` | `#374151` | 본문·테이블 셀 값 |
| `text-muted` | `#6B7280` | 부제·테이블 헤더·캡션 (실측 부제 #5D647A) |
| `text-subtle` | `#9CA3AF` | 플레이스홀더·비활성·보조 라벨 |

### 1.4 Semantic — 뱃지/칩 계열

목업의 자사 유사영상 뱃지(없음/1개/2개)와 콘텐츠 갭 분류에서 추출. 겹침이 많아질수록 warm→red로 간다.

| 상태 | 배경 | 텍스트 | 실측 근거 | 쓰임 |
|---|---|---|---|---|
| `neutral` | `#F2F4F7` | `#4B5563` | 없음 뱃지 | 자사 유사영상 없음 · 콘텐츠 갭 "미제작" |
| `caution` (amber) | `#FEF1E3` | `#F56B04` | 1개 뱃지 | 유사영상 1개 · 갭 "유사 1개" · 경고 플래그 |
| `danger` (red) | `#FEEEEF` | `#C31334` | 2개 뱃지 | 유사영상 2개+ · 갭 "포화" |

경고 전용 amber 램프(정직성 상태에서 재사용):

| 토큰 | Hex | 용도 |
|---|---|---|
| `warning-50` | `#FEF3E4` | 경고 배경 |
| `warning-500` | `#F59E0B` | 경고 아이콘·보더 |
| `warning-600` | `#B45309` | 경고 텍스트 |

### 1.5 성과 배수 색 밴드 (PRD FR-8 — 목업에 없음, 필수)

FR-8은 성과 배수를 4구간 색으로 구분하도록 요구한다. 목업은 성과 배수를 한 가지 그린으로만 칠했으므로, 그 그린을 기준으로 **순차(sequential) 램프**를 만든다 — 배수가 클수록 채도·명도가 강해지고 `>10배`는 solid fill로 시각을 지배한다. amber/red는 여기 쓰지 않는다(그 색은 정직성 경고·갭 뱃지 전용이라, 성과 배수에 쓰면 "빨강=나쁨"으로 오독된다).

이 밴드는 **대시보드·급상승 테이블·추천 카드 전부에서 동일하게** 쓴다.

| 밴드 | 배경 | 텍스트 | 굵기 | 의미 |
|---|---|---|---|---|
| `mult-neutral` (<2배) | 없음(투명) | `#6B7280` | 400 | 채널 평소 수준 — 강조 안 함 |
| `mult-good` (2~5배) | `#E7F6EC` | `#15803D` | 600 | 양호 |
| `mult-strong` (5~10배) | `#C6EBD1` | `#0F7A38` | 700 | 강함 |
| `mult-breakout` (>10배) | `#159C49` | `#FFFFFF` | 700 | 돌파 — solid pill로 도드라짐 |

`>25배`는 밴드 위에 별도 **"검증 요망" amber 플래그**(§4.7)를 겹쳐 단다. 색 밴드(크기)와 경고(신뢰)는 다른 축이다.

---

## 2. Typography

### 2.1 폰트 스택 — 한·일 글리프 동시 커버 (필수)

화면 데이터에 일본어(자사·경쟁)와 한국어가 섞인다. 브라우저는 스택을 앞에서부터 **글리프 단위로** 폴백하므로, 한 스택에 KR·JP 폰트를 함께 나열하면 각 글리프가 자기 폰트로 렌더된다.

```css
--font-sans: "Pretendard", "Noto Sans KR", "Noto Sans JP",
  system-ui, -apple-system, "Hiragino Kaku Gothic ProN",
  "Yu Gothic", "Meiryo", sans-serif;
```

- `Pretendard`·`Noto Sans KR` — 한국어·라틴·숫자 주력.
- `Noto Sans JP` — 한국어 폰트에 없는 일본어 전용 글리프(かな·일부 한자) 폴백.
- Rails에서는 `Noto Sans KR`/`Noto Sans JP`를 self-host(`app/assets/fonts`)하거나 `@fontsource`로 번들. 무게는 400/500/600/700만 로드.
- 숫자에는 반드시 `font-variant-numeric: tabular-nums`(조회수·성과 배수·점수 세로 정렬).

### 2.2 타입 스케일

| 토큰 | size / line | weight | 용도 |
|---|---|---|---|
| `text-score` | 40px / 1.1 | 800 | 기회 점수(89)·도넛 중앙(68%) 등 숫자 강조 |
| `text-h1` | 28px / 1.3 | 700 | 페이지 제목("YouTube 콘텐츠 리서치") |
| `text-h2` | 20px / 1.35 | 700 | 섹션 제목("급상승 영상", "이번 주 추천 콘텐츠 3개") |
| `text-h3` | 18px / 1.4 | 600 | 카드 제목(추천 카드 영상 제목) |
| `text-nav` | 15px / 1.4 | 500 | 좌측 내비 항목 |
| `text-body` | 14px / 1.5 | 400–500 | 본문·테이블 셀 |
| `text-caption` | 13px / 1.45 | 400 | 부제·보조 설명·근거 라인 |
| `text-label` | 12px / 1.4 | 500 | 테이블 헤더·뮤트 라벨·뱃지 텍스트 |

기회 점수의 `/100`, 도넛의 부가 라벨은 `text-label` 굵기 400 뮤트로 큰 숫자에 종속시킨다(목업 그대로).

---

## 3. Radius · Spacing · Elevation

### 3.1 Radius

| 토큰 | 값 | 대상 |
|---|---|---|
| `radius-card` | 12px | 카드·위젯·큰 컨테이너 (Tailwind `rounded-xl`) |
| `radius-control` | 8px | 버튼·기간 탭·드롭다운·검색바·번호 뱃지 (`rounded-lg`) |
| `radius-chip` | 6px | 태그/뱃지/칩(문법·초급~중급·없음·1개) (`rounded-md`) |
| `radius-full` | 9999px | 아바타·채널 원형 이니셜·상태 dot (`rounded-full`) |

### 3.2 Spacing (4px 베이스)

| 토큰 | 값 | 용도 |
|---|---|---|
| `space-card-p` | 24px | 카드/위젯 안쪽 패딩 (`p-6`) |
| `space-grid-gap` | 20px | 위젯 간 그리드 간격 (`gap-5`) |
| `space-section` | 28px | 섹션 세로 리듬 |
| `space-inline` | 8px | 아이콘–텍스트, 칩 간 간격 |
| `space-cell-y` / `space-cell-x` | 12px / 16px | 테이블 셀 패딩 |
| `nav-width` | 180px | 좌측 내비 폭(실측 ~186px) |
| `nav-item-p` | 10px 12px | 내비 항목 패딩, 아이콘–라벨 gap 12px |
| `content-p` | 24–32px | 본문 영역 좌우 패딩 |

테이블 행 높이 ≈ 56–64px(썸네일 행). 추천 카드는 3열 균등 그리드, 하단 우측은 2:1(급상승 테이블 : 경쟁채널+도넛) 비율.

### 3.3 Elevation (그림자)

목업 카드는 보더 + 아주 옅은 그림자로 뜬다. 과한 그림자 금지.

| 토큰 | 값 |
|---|---|
| `shadow-card` | `0 1px 2px rgba(16,24,40,0.04), 0 1px 3px rgba(16,24,40,0.06)` |
| `shadow-card-hover` | `0 2px 4px rgba(16,24,40,0.06), 0 4px 8px rgba(16,24,40,0.08)` |
| `shadow-dropdown` | `0 4px 12px rgba(16,24,40,0.10)` |

---

## 4. Components

모든 컴포넌트는 §1–3 토큰만 쓴다. 새 색·radius 도입 금지.

### 4.1 좌측 내비 항목

- 컨테이너: `nav-width` 180px, `surface` 배경, 우측 `border-default` 1px.
- 항목: 아이콘 + 라벨, `nav-item-p`, `radius-control`, `text-nav`.
- **기본**: 텍스트 `text-muted`, 아이콘 `text-subtle`, 배경 투명.
- **활성**: 배경 `primary-600`, 텍스트·아이콘 `#FFFFFF` (목업 "대시보드").
- **hover(비활성)**: 배경 `primary-50`, 텍스트 `primary-600`.
- 하단: "데이터 범위" 안내 박스 — `surface-sunken` 배경, `radius-card`, `text-label` 뮤트, "자세히 보기 →" 링크는 `primary-600`.

### 4.2 추천 카드 (이번 주 추천 콘텐츠 3개)

- `surface` / `radius-card` / `space-card-p` / `border-default` / `shadow-card`.
- **번호 뱃지**: 28px 정사각, `radius-control`, `primary-600` 배경, 흰 숫자 700.
- **제목**: `text-h3`, `text-strong`, 최대 2줄 `line-clamp-2`(§7 다국어 규칙).
- **태그 칩**: `radius-chip`, `primary-50` 배경, `primary-600` 텍스트, `text-label`(문법·초급~중급).
- **스탯 라인**: 작은 아이콘(`text-subtle`) + `text-body`. "경쟁 영상 N개 상승 / 성과 배수 N배 / 자사 유사영상 유무".
- **기회 점수**: `text-score` `primary-600` + `/100` 뮤트 라벨. 우측 정렬 강조.
- **근거 보기 버튼**: outline 버튼(§4.8) — 텍스트·보더 `primary-600`, 배경 투명, `→` 아이콘.
- 라벨 정합: "구독자 대비 조회수" 금지 → "성과 배수(채널 평소 대비)"(§9).

### 4.3 데이터 테이블 (급상승 영상)

컬럼: `# / 영상(썸네일+제목) / 채널 / 업로드일 / 조회수 / 성과 배수 / 트렌드 / 자사 유사영상`.

- **헤더 행**: `surface-sunken` 배경 또는 `border-subtle` 하단선, `text-label` `text-muted`.
- **본문 행**: 높이 56–64px, 하단 `border-subtle` 구분선, hover 시 `surface-sunken`.
- **썸네일**: 16:9, `radius-chip`, 폭 ~72–80px.
- **제목 셀**: `text-body` `text-strong`, 1줄 `truncate` + `title` 툴팁(§7). `min-w-0` 필수.
- **채널 셀**: `text-body` `text-muted`, 1줄 truncate.
- **조회수(뮤트 컬럼)**: `text-body` `text-muted`, `tabular-nums`. 2차 정보로 강등(성과 배수보다 약하게).
- **성과 배수(히어로 셀)**: §1.5 색 밴드 적용, `tabular-nums`. 이 셀이 raw 조회수보다 강조된다.
- **트렌드**: 스파크라인(§4.6) 또는 콜드 스타트 시 §4.9 플레이스홀더.
- **자사 유사영상**: §1.4 뱃지(없음=neutral / 1개=caution / 2개+=danger).

### 4.4 뱃지 / 칩

- 공통: `radius-chip`, `text-label`, 패딩 `2px 8px`, `inline-flex items-center`.
- **태그 칩**(문법·회화·학습법·초급~중급): `primary-50` / `primary-600`.
- **자사 유사영상 뱃지**: §1.4 3종.
- **영상 유형 뱃지**(쇼츠/롱폼, PRD FR-11): `neutral` 톤 + 아이콘. 쇼츠/롱폼 절대 섞지 않음.
- **성과 배수 pill**: §1.5 밴드.

### 4.5 경쟁 채널 동향 리스트

- 각 행: 원형 이니셜 아바타(`radius-full`, 채널별 파스텔 배경 + 진한 글자) + 채널명(`text-body` truncate) + 구독자(`text-muted` tabular) + 구독자 증감.
- **증감**: 미니 진행 바(`success-600` 채움 / `border-subtle` 트랙) + `success-600` 퍼센트.
- 규모 임계 미만 채널: 증감 자리에 §4.7 "측정한계" 라벨.

### 4.6 도넛 + 범례 (콘텐츠 기회) · 스파크라인

- **도넛**: 4구간을 **뚜렷이 구분되는 색**으로(운영자 요청·목업 색 구분). 미제작 `primary-600`(기회·중앙 %와 동일) / 유사 1개 `success-600` / 유사 2개+ `warning-500` / 포화 `ink-subtle`(중립 회색). 트랙은 `border`. 중앙 `text-score` `primary-600`(68%).
- **범례**: 색 dot(`radius-full`) + 라벨 `text-body` + 값 `text-muted tabular`. 4구간(미제작/유사 1개/유사 2개+/포화).
- **스파크라인**: `primary-600` 라인 1.5px, 채움 없음 또는 `primary-50` 아주 옅게. 마지막 점만 dot.
- 색 매핑 규칙은 프로젝트 `dataviz` 스킬 팔레트가 아니라 이 문서를 따른다.

### 4.7 정직성 상태 (PRD §8 NFR — 목업에 없음, 필수)

불확실성을 임시방편이 아니라 **디자인의 일부로** 보이게 한다.

- **"데이터 수집 중"(콜드 스타트 플레이스홀더)** — 위젯 자리·크기 유지. 내용만 교체: `bg-app` 배경, `border-default` **대시(dashed)** 보더, 중앙 `text-subtle`로 "D+n · 데이터 수집 중". 스켈레톤 pulse(§6) 허용. 값 없다고 위젯을 숨기지 않는다.
- **"측정한계" 라벨** — 소형 채널 구독자 증감 자리. `neutral` 칩(`#F2F4F7`/`#6B7280`) `text-label`. 숫자 대신 이 라벨.
- **에버그린 후보 vs 에버그린(검증)** — 시각적으로 확신도 차이를 준다.
  - `후보`: **ghost 뱃지** — 투명 배경, `success-100` 보더, `success-700` 텍스트. "후보" 접미. (잠정)
  - `검증`: **solid 뱃지** — `success-600` 배경, 흰 텍스트, ✓ 아이콘. (확정)
- **"검증 요망"(성과 배수 >25배)** — amber 경고 플래그: `warning-50` 배경, `warning-600` 텍스트, `warning-500` 보더, ⚠ 아이콘. 성과 배수 밴드 위에 겹쳐 단다.
- **신뢰도 하한(표본 <10개)** — 미세 caution 플래그: `warning-600` 텍스트의 작은 ⚑ 또는 "저신뢰" `text-label`, 툴팁으로 "최근 공개 영상 N개 — 신뢰도 낮음". 값을 가리지 않고 옆에 표식만.

이 상태들은 §1의 정식 토큰만 쓰므로 나머지 UI와 한 몸으로 보인다.

### 4.8 버튼 · 탭 · 드롭다운 · 검색바

- **Primary 버튼**: `primary-600` 배경, 흰 텍스트 600, `radius-control`, 패딩 `8px 14px`. hover `primary-700`.
- **Outline 버튼**("근거 보기", "오늘 업데이트", "전체 보기 →"): 투명 배경, `border-default` 보더, `primary-600` 텍스트·아이콘. hover 배경 `primary-50`.
- **+ 원형 버튼**(헤더): `primary-600` 배경 원형, 흰 +.
- **기간 탭**: 세그먼트. 활성 = `primary-600` 배경 흰 텍스트 `radius-control`. 비활성 = 투명 배경 `text-muted`. hover `primary-50`.
- **드롭다운**(카테고리/유형): `surface` 배경, `border-default`, `radius-control`, `text-body`, 우측 chevron `text-subtle`. 메뉴 `shadow-dropdown`.
- **검색바**: `surface`, `border-default`, `radius-control`, 좌측 돋보기 `text-subtle`, placeholder `text-subtle`.

### 4.9 스켈레톤 / 로딩

- 콜드 스타트·데이터 로딩: `surface-sunken` 블록 + pulse(§6), 실제 레이아웃 치수 유지(레이아웃 시프트 방지).

---

## 5. Responsive (PC 중심, 모바일 안 깨짐)

Tailwind 기본 브레이크포인트: `sm 640 · md 768 · lg 1024 · xl 1280`.

| 구간 | 좌측 내비 | 본문 레이아웃 | 테이블 |
|---|---|---|---|
| `< md` (모바일) | 상단 바 + 햄버거(오버레이 드로어) 또는 아이콘 레일로 축소 | 추천 카드 1열 스택, 우측 위젯(경쟁채널·도넛) 아래로 스택 | `overflow-x-auto` **가로 스크롤**, 셀에 `min-width` 부여 |
| `md ~ lg` | 아이콘 레일(72px) 또는 유지 | 추천 카드 2열, 급상승 테이블 전폭 | 가로 스크롤 유지 |
| `≥ xl` | 풀 내비 180px | 목업 그대로(3열 추천 + 2:1 하단) | 전폭 |

- 테이블은 절대 컬럼을 접어 뭉개지 말고 **가로 스크롤**로 온전히 유지(PRD §4). 스크롤 컨테이너에 `-webkit-overflow-scrolling: touch`.
- 필터 탭이 좁으면 가로 스크롤 허용, 본문(`body`)은 절대 가로 스크롤 금지.
- 기간 탭·드롭다운은 모바일에서 세로 스택 또는 스크롤 행.

---

## 6. Motion

절제. 정보 대시보드라 화려한 모션 금지.

- 트랜지션 기본: `150ms ease` (버튼·탭·hover·드롭다운 열림).
- 카드 hover: `shadow-card → shadow-card-hover`, translateY 없음 또는 -1px 이내.
- 스켈레톤/콜드 스타트: `pulse` 1.5s ease-in-out infinite(opacity 1↔0.5).
- 도넛·스파크라인 최초 렌더: 300ms 이내 draw-in 허용(선택).
- 페이지 전환 애니메이션 없음(서버 렌더).

---

## 7. 다국어 텍스트 대응 (필수 — 실데이터에서 반드시 터짐)

영상 제목이 일본어·한국어 혼재다(자사=일본어, 경쟁=한·일 혼재). 목업엔 안 드러나지만 실제 데이터에서 레이아웃이 깨진다.

- **폰트**: §2.1 스택이 KR·JP 글리프를 글리프 단위 폴백으로 커버.
- **언어 힌트**: 값의 언어를 알면 `lang="ja"` / `lang="ko"`를 셀·요소에 부여 — 폰트 선택과 줄바꿈 규칙(일본어 금칙 처리, 한국어 어절)이 정확해진다.
- **한국어 줄바꿈**: `word-break: keep-all`(어절 중간에서 안 끊김) + `overflow-wrap: anywhere`(초장문 방어).
- **말줄임 / 줄 제한**:
  - 카드 제목: 2줄 `line-clamp-2` + `…`.
  - 테이블 제목 셀: 1줄 `truncate`(`text-overflow: ellipsis`) + `title` 속성으로 전체 노출(hover 툴팁).
  - 채널명·태그: 1줄 truncate.
- **flex/grid 안 truncate**: 부모에 `min-w-0` 필수(안 그러면 말줄임이 안 먹고 셀이 밀림).
- **긴 일본어**: 공백이 없어 `break-word`로도 잘 안 끊긴다 → truncate/line-clamp로 폭을 강제하고, 필수 노출은 툴팁으로.
- 숫자·배수·점수는 `tabular-nums`로 자릿수 정렬(혼합 언어와 무관하게 우측 정렬 유지).

---

## 8. Voice / Microcopy

- 정직하고 간결한 한국어. 불확실성을 숨기지 않는다(PRD §8).
- **용어는 PRD §3 Glossary에 고정** — 화면 어디에도 "구독자 대비 조회수" 없음. **"성과 배수(채널 평소 대비)"** 로 통일(§9, PRD §11 강제).
- 상태 문구도 Glossary 그대로: "데이터 수집 중" · "측정한계" · "에버그린 후보" · "에버그린(검증)" · "검증 요망" · "저신뢰".
- 한국어 문장은 마침표로 끝낸다(라벨·`key: value`의 콜론은 정상).

---

## 9. 라벨 정합 (강제 — PRD §11)

목업의 **"구독자 대비 조회수 N배"** 표현은 전 화면에서 **"성과 배수(채널 평소 대비) N배"** 로 교체한다. 시각 레이아웃(위치·크기·색 밴드)은 목업 그대로 두고 **문구만** 방법론에 맞춘다. 이건 선택이 아니라 PRD 강제 사항이다.

---

## 10. Tailwind 매핑 (운영자가 직접 고칠 지점)

`tailwind.config.js`(또는 Rails `config/tailwind.config.js`)의 `theme.extend`에 그대로 옮긴다. 색을 바꾸려면 여기 한 곳만 고치면 전 화면에 반영된다.

```js
// SPARTA Content Lab 디자인 토큰 → Tailwind 매핑. 값은 DESIGN.md가 원천.
module.exports = {
  theme: {
    extend: {
      colors: {
        primary: { 50:'#EEF2FE',100:'#DCE4FD',500:'#2E5BE6',600:'#1145DD',700:'#0E37B0' },
        success: { 50:'#E7F6EC',100:'#C6EBD1',600:'#159C49',700:'#0F7A38' },
        warning: { 50:'#FEF3E4',500:'#F59E0B',600:'#B45309' },
        // 성과 배수 밴드
        mult: { good:'#15803D', strong:'#0F7A38', breakout:'#159C49' },
        // 뱃지
        badge: { neutralBg:'#F2F4F7', neutralFg:'#4B5563',
                 cautionBg:'#FEF1E3', cautionFg:'#F56B04',
                 dangerBg:'#FEEEEF',  dangerFg:'#C31334' },
        app:     '#FBFCFD',
        surface: { DEFAULT:'#FFFFFF', sunken:'#F7F8FA' },
        border:  { DEFAULT:'#E5E7EB', subtle:'#EEF1F5' },
        ink:     { strong:'#111827', body:'#374151', muted:'#6B7280', subtle:'#9CA3AF' },
      },
      fontFamily: {
        sans: ['Pretendard','Noto Sans KR','Noto Sans JP','system-ui',
               '-apple-system','Hiragino Kaku Gothic ProN','Yu Gothic','Meiryo','sans-serif'],
      },
      fontSize: {
        score:   ['40px',{ lineHeight:'1.1',  fontWeight:'800' }],
        h1:      ['28px',{ lineHeight:'1.3',  fontWeight:'700' }],
        h2:      ['20px',{ lineHeight:'1.35', fontWeight:'700' }],
        h3:      ['18px',{ lineHeight:'1.4',  fontWeight:'600' }],
        nav:     ['15px',{ lineHeight:'1.4',  fontWeight:'500' }],
        body:    ['14px',{ lineHeight:'1.5' }],
        caption: ['13px',{ lineHeight:'1.45' }],
        label:   ['12px',{ lineHeight:'1.4',  fontWeight:'500' }],
      },
      borderRadius: { card:'12px', control:'8px', chip:'6px' },
      boxShadow: {
        card:      '0 1px 2px rgba(16,24,40,0.04), 0 1px 3px rgba(16,24,40,0.06)',
        cardHover: '0 2px 4px rgba(16,24,40,0.06), 0 4px 8px rgba(16,24,40,0.08)',
        dropdown:  '0 4px 12px rgba(16,24,40,0.10)',
      },
    },
  },
}
```

성과 배수 밴드는 유틸 클래스보다 헬퍼 함수로 매핑하는 게 낫다(값→밴드 룩업):

```ruby
# 성과 배수 값을 §1.5 색 밴드 CSS 클래스로 매핑
def performance_band_class(multiple)
  case multiple
  when 0...2   then "text-ink-muted"                      # <2배 중립
  when 2...5   then "bg-success-50 text-mult-good font-semibold"
  when 5...10  then "bg-success-100 text-mult-strong font-bold"
  else              "bg-success-600 text-white font-bold"  # >10배 돌파
  end
end
```

---

## 11. 사용 규칙 (구현 세션용)

1. 색·간격·radius·폰트는 이 문서(또는 §10 Tailwind 매핑)에서만 가져온다. `blue-600`·`indigo-500` 같은 원시 Tailwind 색 직접 사용 금지.
2. "성과 배수" 관련 UI는 §1.5 밴드를 그대로 쓴다. 화면마다 다시 색을 정하지 않는다.
3. 정직성 상태(§4.7)는 위젯을 숨기지 말고 자리 유지 + 상태 표시.
4. 다국어(§7) 규칙은 제목·채널명이 들어가는 모든 셀에 적용.
5. 목업과 다르게 가고 싶은 지점이 생기면 임의로 바꾸지 말고 운영자에게 묻는다.
