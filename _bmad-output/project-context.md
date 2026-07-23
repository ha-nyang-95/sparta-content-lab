---
project_name: 'Youtube-planning-helper'
user_name: 'hwan'
date: '2026-07-23'
sections_completed: ['technology_stack', 'critical_rules', 'naming', 'data', 'testing']
source_of_truth: '_bmad-output/planning-artifacts/architecture/architecture-Youtube-planning-helper-2026-07-22/ARCHITECTURE-SPINE.md'
---

# Project Context for AI Agents — SPARTA Content Lab

_이 파일은 구현 워크플로우(dev-story·quick-dev)가 매번 자동 로드한다. ARCHITECTURE-SPINE.md는 자동 로드되지 않으므로, 그 불변식(AD-1~17) 중 **코드에서 자주 어기는 규약만** 여기에 압축했다. 권위는 스파인 전문에 있다 — 충돌 시 스파인이 이긴다. UI 토큰 규칙은 CLAUDE.md/DESIGN.md가 이미 상속시키므로 여기선 참조만 한다._

---

## 1. 기술 스택 (파이썬 아님 — Rails)

| 항목 | 버전 / 값 | 어기기 쉬운 지점 |
| --- | --- | --- |
| Ruby on Rails | **8.x** | 서버 렌더(ERB). SPA·API-only 아님 |
| SQLite | 3.x — **WAL + 멀티DB** | app / queue / cache 3개 파일 분리(AD-12). Redis·Postgres 없음 |
| Solid Queue | Rails 8 기본, SQLite 백엔드 | recurring 잡. Sidekiq 아님 |
| Solid Cache | Rails 8 기본, 별도 DB 파일 | |
| Tailwind CSS | **v3.x (핀 필수)** | `tailwindcss-rails` 기본이 4.x이므로 **v3로 핀**. `config/tailwind.config.js` + `theme.extend` 관용구. v4 CSS `@theme` 금지(Deferred) |
| YouTube Data API | v3 | 서비스 경계에서만(AD-1) |
| 임베딩 | **gemini-embedding-001** (유료) | 다른 임베딩 모델로 대체 금지 |

> 언어는 **Ruby**다. Python·Node 백엔드 코드를 생성하지 않는다.

## 2. 절대 규칙 (아키텍처 불변식 — 코드로 자주 어김)

1. **외부 API 호출은 `app/services` 경계에서만** (AD-1). YouTube·Gemini 호출을 컨트롤러·모델·뷰·잡에서 `Net::HTTP`/SDK로 직접 하지 않는다. YouTube 호출은 전부 `app/services/youtube/*`를 통과한다(단일 쿼터 원장 — 공유 1만 units + `search.list` 100콜/일 버킷).
2. **스코어링 계산은 `app/services/scoring`에서만** (AD-2). 기준선·성과 배수·플루크 방어·기회 점수 정규화 공식을 뷰·잡·모델에 복제하지 않는다.
   - **성과 배수 = 영상 누적 `view_count` ÷ (같은 채널·같은 `video_type` 최근 N개 공개 영상 `view_count`의 중앙값)**. 평균 아님, age-matched 아님.
   - **기회 점수** = 4입력(성과 배수 신호·경쟁 공통성·콘텐츠 갭·최신성) 각각 [0,1] 정규화 → 가중합 → ×100. 이 **구조는 불변**, 값만 설정(AD-4). 성과 배수 하나로 대체하지 않는다.
   - **동점 처리는 코드에 고정** — 기회 점수 동점 시 성과 배수 → 최신성 순.
   - 성과 배수(성과)와 VPD(모멘텀)를 **하나의 종합 점수로 합산 금지** — 별도 축.
3. **무거운 파생 지표는 배치에서 물질화** (AD-3). 성과 배수·기회 점수·콘텐츠 갭 버킷·자사 유사영상은 배치가 DB 컬럼/테이블에 써두고, **웹 요청 경로는 읽기만** 한다. 요청 경로에서 임베딩·유사도·중앙값 재계산 금지(P95 2초).
4. **튜닝값은 `config/scoring.yml`에서만 읽는다** (AD-4). 코드 상수로 하드코딩 금지 대상 — 기준선 N·유사도 τ·기회 점수 가중치와 정규화 매핑·에버그린 나이/배수 임계·조회수 하한(고정값·k)·구독자 규모 임계·극단배수(25x)·위젯별 전환 스냅샷 수·**is_short duration 임계**. 값은 본개발 실측이고 스파인은 자리만 고정했다.
5. **API 키는 Rails credentials 또는 ENV로만**, 서비스 경계에서만 읽는다. 리포·코드 하드코딩 금지.
6. **원시 Tailwind 색(`blue-600` 등) 직접 사용 금지** (AD-15). `DESIGN.md` §10 토큰만 사용(CLAUDE.md 상속 규칙 — 상세는 DESIGN.md).

## 3. 파이프라인·경계 (필터 순서가 곧 의존)

- **두 파이프라인 분리** (AD-11) — 일1회 `DailyCollectionJob`, 주1회 `WeeklyDiscoveryJob`. 각각 별도 Solid Queue recurring. 잡은 체인 조립만 하고 로직은 서비스에 위임한다.
- **일일 체인 순서(스테이지 의존, 바꾸지 말 것)** — `channels.list → playlistItems.list → videos.list(배치 50) → 일별 스냅샷 저장 → 기준선/성과 배수 → 에버그린 후보 → 임베딩(신규/제목변경만) → OwnVideoMatch → 콘텐츠 갭 버킷 → 주제 클러스터(휘발) → 기회 점수·추천 3개(스냅샷 저장)`. 콘텐츠 갭은 OwnVideoMatch 없이, OwnVideoMatch는 임베딩 없이 계산할 수 없다.
- **한 파생값의 writer는 한 스테이지뿐.** 각 스테이지는 이전 산출을 DB에서 읽어 다음 산출을 DB에 쓴다.
- 의존 방향 — Model·View·Helper는 Service를 부르지 않는다. Service는 Controller·Job을 모른다.

## 4. 네이밍 컨벤션

- **AR 모델** — 단수 PascalCase. `Video`, `VideoDailyStat`, `ChannelDailyStat`, `Baseline`, `TopicCluster`, `Recommendation`, `SavedVideo`, `OwnVideoMatch`, `JobRun`.
- **YouTube 식별자** — `youtube_*_id` 컬럼(예 `youtube_video_id`)으로 내부 PK와 구분한다.
- **서비스** — `app/services/<domain>/` 하위 **동사형 클래스**. `Scoring::CalculateBaseline`, `Youtube::FetchVideos`, `Embedding::UpsertVectors`, `Youtube::ClassifyShort`, `Youtube::OwnVideoMatch`.
- **잡** — `<주기><동작>Job`. `DailyCollectionJob`, `WeeklyDiscoveryJob`.

## 5. 데이터 규약

- **스냅샷 날짜 경계는 `Asia/Tokyo`** (앱 고정 타임존, JP 대상·수집 시각 기준). 시각 자체는 UTC `datetime`. 경계 흔들림으로 인한 중복/누락을 막는다.
- **유니크 제약** — `(video_id, date)`·`(channel_id, date)`. 같은 날 중복 스냅샷 행이 생기지 않는다(AD-5).
- **일별 스냅샷이 모든 시계열의 단일 원천** — `video_daily_stats`·`channel_daily_stats`가 VPD·에버그린·구독자 증감·스파크라인의 유일 원천.
- **nil 방어** (AD-9) — 회원 전용 영상은 `view_count` nil로 저장하고 기준선 표본·성과 비교에서 **제외**한다. `like_count`/`comment_count` 누락도 nil 방어. 자사 회원 전용 영상은 제목·주제 매칭까지만, 성과 수치는 표시하지 않는다.
- **duration은 초 정수로 저장** — ISO 8601 원본은 버린다.
- **쇼츠/롱폼 완전 분리** (AD-8) — 기준선·필터·표시에서 중앙값을 절대 공유하지 않는다. `is_short`는 **`Youtube::ClassifyShort`가 영상 최초 저장 시 1회** duration 휴리스틱으로 판정해 캐시하고 이후 불변(두 writer/두 임계 금지). 임계는 `config/scoring.yml`.
- **임베딩은 BLOB + Ruby 코사인** (AD-10) — `videos`의 packed-float BLOB 컬럼. `embedding_source_hash`(제목 기준)가 바뀐 행만 재생성. sqlite-vec 미채택. `Recommendation`은 휘발 `TopicCluster`에 FK하지 않고 `reference_video_ids` + `topic_label`을 스냅샷 저장한다.
- **`Channel.category`는 4분류** — 직접경쟁 / 한국어교육일반 / 언어교육참고 / 상단퍼널. 필터 드롭다운의 데이터 홈.
- `app.sqlite3`(스냅샷 원천)는 **일일 백업 필수**(AD-17) — 소급 재구성 불가. queue/cache DB는 제외.

## 6. 표시 규약 (구현 시 잊기 쉬운 것)

- **기본 정렬키는 성과 배수 내림차순** (AD-15). raw 조회수 기본 정렬 금지. 기본 레이아웃은 구독자 밴드 그룹핑 + 밴드 내 배수 정렬. 성과 배수는 히어로 셀, raw 조회수는 2차 뮤트 컬럼.
- **라벨 통일** — "구독자 대비 조회수" → **"성과 배수(채널 평소 대비)"**.
- **정직성 상태는 위젯을 숨기지 않고 자리 유지** (AD-16). 콜드스타트는 위젯별 준비도로 개별 판정(AD-7) — 전역 플래그 하나로 뭉개지 않는다. 시점 편향 안내(FR-24) 두 기전 모두 명명 — (1) 누적 조회수 사용, (2) 기준선이 최근 N개 젊은 영상.
- 공유 위젯은 `app/views/shared/_*.html.erb` + `app/helpers`로 캡슐화(예 `performance_band_class`). 상세 토큰·색 밴드는 **DESIGN.md** 참조.

## 7. 테스트 관례

- **스코어링 로직은 자사 실측값을 픽스처로** — 공개 조회수 200~4,100 범위. 다음을 테스트로 고정한다.
  - **중앙값** 기준선 계산(평균 아님).
  - **쇼츠/롱폼 분리** — 유형이 섞인 표본에서 중앙값을 공유하지 않음을 검증.
  - **플루크 방어** — 표본 부족·극단배수 상한(25x, 설정값) 동작.
  - **nil 방어** — 회원 전용 nil이 중앙값 표본에서 제외됨.
  - **결정적 동점 처리** — 기회 점수 동점 시 성과 배수 → 최신성 순서.
- 임계·가중치는 픽스처에서도 `config/scoring.yml` 경로로 읽어, 하드코딩 회귀를 테스트가 잡게 한다.
- 코드를 건드렸으면 완료 선언 전 테스트 실행(프로젝트 러너 기준).
