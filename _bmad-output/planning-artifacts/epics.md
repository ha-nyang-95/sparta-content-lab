---
stepsCompleted: ['step-01-validate-prerequisites', 'step-02-design-epics', 'step-03-create-stories']
inputDocuments:
  - _bmad-output/planning-artifacts/prds/prd-Youtube-planning-helper-2026-07-22/prd.md
  - _bmad-output/planning-artifacts/architecture/architecture-Youtube-planning-helper-2026-07-22/ARCHITECTURE-SPINE.md
  - DESIGN.md
  - _bmad-output/project-context.md
---

# SPARTA Content Lab — Epic Breakdown

## Overview

This document provides the complete epic and story breakdown for **SPARTA Content Lab** (YouTube 콘텐츠 리서치·주제 추천 대시보드), decomposing the confirmed 26 FRs from the PRD, the DESIGN.md UX contract, and the Architecture Spine (AD-1~17) into implementable stories.

**분해 원칙** — 에픽 배열은 아키텍처 AD-11의 **일일 파이프라인 체인이 곧 의존 순서**다. `channels.list → 스냅샷 → 기준선/성과 배수 → 에버그린 후보 → 임베딩 → OwnVideoMatch → 콘텐츠 갭 → 주제 클러스터 → 기회 점수 → 추천 3개`. 앞 에픽이 뒤 에픽의 입력을 만든다. 화면 에픽은 그 데이터가 준비된 뒤에 온다. 새 요구를 발산하지 않고 확정된 FR만 옮긴다.

## Requirements Inventory

### Functional Requirements

**4.1 데이터 수집·갱신 파이프라인**
- **FR-1:** 상시 스케줄러로 추적 채널 통계를 하루 1회 자동 수집한다(서버 재시작 후 스케줄·잡 상태 DB 지속, 실패 시 지수 백오프, 하루 1회 상한).
- **FR-2:** `channels.list`(uploads ID·구독자) → `playlistItems.list`(영상 ID) → `videos.list`(조회수·좋아요·댓글·길이·제목·썸네일·업로드일, 배치 50)로 열거한다. likeCount/commentCount 누락 nil 방어, duration ISO 8601 파싱, 좋아요·댓글은 수집·저장만(채점·표시 미사용).
- **FR-3:** 일별 스냅샷을 축적한다(`(video_id,date)` 유니크, 최근 90일 일단위 후 주단위 롤업).
- **FR-4:** `search.list`를 주 1회 배치로 신규 채널·경쟁 영상 후보 발굴에 쓴다(하루 100콜 상한, 일 1회 갱신과 분리 주기).

**4.2 성과 배수 스코어링 엔진**
- **FR-5:** 성과 배수 = 현재 누적 조회수 ÷ 채널·유형별 기준선(중앙값). 채널·쇼츠/롱폼 독립 계산, 회원 전용 제외, N 튜닝, 시점 편향 UI 명시(FR-24).
- **FR-6:** 신뢰도·플루크 방어 — 유형별 최근 공개 영상 <10개 신뢰도 하한 플래그, 조회수 하한(기준선 상대식 max(고정값, k×기준선)), >25x 극단배수 "검증 요망" 플래그.
- **FR-7:** 성과 배수(성과)와 VPD(모멘텀)를 별도 축으로 유지(합산 금지). VPD는 콜드 스타트에 "수집 중".
- **4.3 통합 대시보드 & 기간 전환**
- **FR-8:** 통합 대시보드 — 기본 정렬키 성과 배수 내림차순, 히어로 셀·색 밴드, raw 조회수 2차 강등, "성과 배수(채널 평소 대비)" 라벨 통일.
- **FR-9:** 기간 전환 — 1주/1개월/3개월(업로드 기간 필터, 콜드스타트 동작) + 에버그린 탭.
- **FR-10:** 구독자 밴드 티어링(<1만/1만~10만/10만~50만/50만+) 그룹핑 + 밴드 내 배수 정렬, 평면 토글.

**4.4 급상승 영상**
- **FR-11:** 급상승 영상 테이블 — 썸네일·제목·채널·업로드일·조회수·성과 배수·자사 유사영상 유무·구독자 밴드·유형 배지·주제 힌트, URL 이동.
- **FR-12:** 트렌드 스파크라인(최근 7일) — 시계열 의존, 콜드스타트 "데이터 수집 중" 플레이스홀더(자리 유지).

**4.5 에버그린 콘텐츠**
- **FR-13:** 에버그린 후보 즉시 노출(대리지표) — 나이 임계 AND 성과 배수 임계 두 조건 동시 충족, "후보" 라벨, 1일차 동작.
- **FR-14:** 에버그린 승격(검증) — 스냅샷 나이-조회 증분 곡선이 낮고 평탄, 콜드스타트 이후, 후보와 시각 구분.

**4.6 경쟁 채널 관리**
- **FR-15:** 경쟁 채널 자동 추천 + URL 수동 등록/제외 — URL 추가 시 다음 주기 반영, 제외 시 대시보드·채점 제외, 시드 목록(channel-analysis §5) 초기 로드.
- **FR-16:** 경쟁 채널 동향 — 채널명·구독자·(조건부)구독자 증감 요약 목록.

**4.7 자사 유사영상 & 콘텐츠 갭**
- **FR-17:** 자사 유사영상 판정 — 임베딩 유사도, 제목 변경 행만 재생성, 임계 실측 튜닝, 코스(회원 전용)=제목·주제 매칭만(성과 수치 미표시).
- **FR-18:** 콘텐츠 갭 분포 — 미제작/유사영상 1개/2개+/포화 4구간 도넛, 행 컬럼과 분류 일치.

**4.8 다음 주 추천 주제 3개**
- **FR-19:** 추천 주제 3개 산출 — 기회 점수·추천 이유·참고 경쟁 영상, 자격 <3개면 "이번 주 N개 확보" 정직 표시, 결정적 동점(기회 점수→성과 배수→최신성).
- **FR-20:** 임베딩 기반 주제 자동 묶기 — 코사인 ≥τ 간선의 연결 요소를 주제 클러스터로, τ는 FR-17 재사용, 1일차 동작, 추가 임베딩 비용 0.
- **FR-21:** 기회 점수 산출 — 4입력(성과 배수 신호·경쟁 공통성·콘텐츠 갭·최신성) 각 [0,1] 정규화 → 가중합 → ×100, 가중치 튜닝, 성과 배수로 대체 불가.

**4.9 구독자 증감 (규모 조건부)**
- **FR-22:** 조건부 구독자 증감 — 7일 스냅샷 후 규모 임계 이상 채널만 표시, 미만은 "측정한계", channels.list 동승(추가 API 비용 0), 소급 미표시.

**4.10 콜드 스타트 상태 처리**
- **FR-23:** 콜드 스타트 상태 표시 — 시계열 위젯(스파크라인·VPD·검증 에버그린·구독자 증감)을 "D+n 데이터 수집 중" 플레이스홀더로, 위젯별 개별 준비도 판정(전역 배너 금지), 1일차 지표는 정상 표시.
- **FR-24:** 시점 정합 편향 명시 — 성과 배수 옆/툴팁에 누적 조회수 기준·편향 안내, **두 기전 모두 명명**((1)누적 조회수, (2)최근 N개 젊은 기준선).

**4.11 검색·필터·정렬**
- **FR-25:** 검색·필터·정렬 — 키워드·채널·유형·업로드 기간·조회수·성과 배수·구독자 밴드, 배수 프리셋(2x/3x/5x/10x/25x), 쇼츠/롱폼 필터 분리.
- **FR-26:** 영상 저장 — 관심 영상을 저장 목록에 담고 "저장한 영상" 화면에서 재열람.

### NonFunctional Requirements

- **NFR-1 수집 지속성:** 스케줄러 상시 실행, 서버 재시작 후 스케줄·잡 상태 지속(로컬 중단 문제 해소).
- **NFR-2 동시성:** SQLite WAL(Rails 8 기본) + busy_timeout 5000ms, 단일 라이터(배치 트랜잭션 짧게), Solid Queue/Cache 별도 DB 파일.
- **NFR-3 레이트리밋 내성:** 정식 API 실패(403 quota/rate) 지수 백오프 재시도. 스크래핑성 IP 차단은 API 채택으로 해소.
- **NFR-4 성능:** 대시보드 첫 로드·정렬·필터 전환 통상 데이터에서 P95 2초 목표(유사도·수집은 배치라 요청 경로 제외).
- **NFR-5 가용성 기대치:** 내부 2인·주 1회 도구, 고가용성 불요, 수집 1일 실패 다음 주기 복구 허용.
- **NFR-6 관측성:** 수집 잡 성공/실패/재시도 이력 DB 기록·확인 가능.
- **NFR-7 정직성(UI):** 콜드 스타트·시점 편향·구독자 반올림 한계·에버그린 후보/검증 구분을 화면에 정직 표시(불확실성 은폐 금지).

### Additional Requirements

_아키텍처 스파인(AD-1~17)·스택·컨벤션이 구현·스토리 형태에 강제하는 기술 요구._

- **AR-Setup (스타터 템플릿):** Rails 8.x greenfield 신규 앱. 인증은 `bin/rails generate authentication`(AD-14)이 만드는 `User`·세션·`has_secure_password`를 쓰고 운영 2인을 seed 등록. **Epic 1 Story 1의 스타터.**
- **AR-Stack:** Ruby on Rails 8.x / SQLite 3.x(WAL·멀티DB) / Solid Queue·Solid Cache(Rails 8 기본, SQLite 백엔드) / **Tailwind CSS v3.x 핀 필수**(`tailwindcss-rails` 기본 4.x → v3 핀) / YouTube Data API v3 / **gemini-embedding-001(유료, 대체 금지)**. 언어는 Ruby(Python·Node 백엔드 금지).
- **AR-1 (AD-1):** 모든 YouTube 호출은 `app/services/youtube/*` 경계 단일 통과 — 단일 쿼터 원장(공유 1만 units + search.list 100콜/일 버킷, 재시도 소비 포함). 컨트롤러·모델·뷰·잡 직접 호출 금지.
- **AR-2 (AD-2):** 기준선·성과 배수·플루크 방어·기회 점수 정규화는 `app/services/scoring/*`에서만. 지표 정의·결정적 동점 처리 코드 고정.
- **AR-3 (AD-3):** 성과 배수·기회 점수·콘텐츠 갭 버킷·자사 유사영상은 배치 물질화, 웹 요청 경로는 읽기만(재계산 금지).
- **AR-4 (AD-4):** 튜닝값(기준선 N·τ·기회 점수 가중치·에버그린 임계·조회수 하한·구독자 임계·25x·위젯 전환 스냅샷 수·is_short duration 임계)은 `config/scoring.yml` 단일 설정. 코드 상수 하드코딩 금지 — **값은 본개발 실측, 스파인은 자리만 고정.**
- **AR-5 (AD-5):** `video_daily_stats`·`channel_daily_stats`가 모든 시계열의 단일 원천, `(video_id,date)`·`(channel_id,date)` 유니크.
- **AR-6 (AD-6):** 90일 후 주단위 롤업 + 원본 삭제 + 주기 VACUUM(일일 잡 동승).
- **AR-7 (AD-7):** 콜드스타트는 위젯별 준비도 개별 판정(전역 플래그 금지), 최소 스냅샷 수는 AD-4 설정.
- **AR-8 (AD-8):** 쇼츠/롱폼 완전 분리(중앙값 미공유). `is_short`는 `Youtube::ClassifyShort`가 최초 저장 시 1회 판정·캐시, 이후 불변(단일 writer·단일 임계).
- **AR-9 (AD-9):** 회원 전용/누락 통계 nil 방어(기준선·비교 제외, 파이프라인 미중단).
- **AR-10 (AD-10):** 임베딩 packed-float BLOB + Ruby 코사인(sqlite-vec 미채택), `embedding_source_hash` 변경 행만 재생성, `Recommendation`은 휘발 `TopicCluster`에 FK 금지 — `reference_video_ids`+`topic_label` 스냅샷 저장.
- **AR-11 (AD-11):** `DailyCollectionJob`(일1회)·`WeeklyDiscoveryJob`(주1회) 분리 Solid Queue recurring. 일일 체인 순서 = 스테이지 의존(콘텐츠 갭은 OwnVideoMatch 없이, OwnVideoMatch는 임베딩 없이 계산 불가). 잡은 체인 조립만, 로직은 서비스.
- **AR-12 (AD-12):** app/queue/cache 3개 SQLite 파일 분리(멀티DB), WAL + busy_timeout 5000ms, Redis 없음.
- **AR-13 (AD-13):** `job_runs` 테이블에 시작·성공·실패·재시도·쿼터 사용량 기록, 403 지수 백오프(재시도는 일1회 상한 제외).
- **AR-14 (AD-14):** 인증 세션 기반, 운영 2인 seed, 목업 아바타 2인과 정합. 멀티테넌시·외부 회원 관리 범위 밖.
- **AR-15 (AD-15):** 공유 위젯은 `app/views/shared/_*.html.erb` + `app/helpers` 캡슐화, DESIGN.md §10 토큰을 `config/tailwind.config.js` `theme.extend`로 이관, 원시 Tailwind 색 직접 사용 금지.
- **AR-16 (AD-16):** 정직성 상태는 위젯 숨기지 않고 자리 유지(DESIGN.md §4.7) — AD-7·AD-8·AD-9의 UI 표면.
- **AR-17 (AD-17):** `app.sqlite3`(스냅샷 원천) 일일 백업 필수(소급 재구성 불가), queue/cache DB 제외.
- **AR-Secrets:** API 키(YouTube·Gemini)는 Rails credentials 또는 ENV로만, 서비스 경계에서만 읽기. 리포·코드 하드코딩 금지.
- **AR-Data-format:** 스냅샷 date 하루 경계 `Asia/Tokyo` 고정, 시각은 UTC datetime, duration 초 정수 저장(ISO 8601 원본 폐기), `Channel.category` 4분류(직접경쟁/한국어교육일반/언어교육참고/상단퍼널).
- **AR-Backfill (자리만):** 최초 1회 전체 영상 열거(~400 units) + 전량 임베딩은 정상 일일 체인과 분리된 1회성 `BackfillJob` seam. 세부 실행은 본개발.

### UX Design Requirements

_DESIGN.md는 AD-15가 지정한 UI 단일 원천. 각 항목은 테스트 가능한 스토리로 실현된다._

- **UX-DR1 (§10 토큰 이관):** DESIGN.md §10 토큰을 `config/tailwind.config.js` `theme.extend`로 이관 — primary `#1145DD`·success `#159C49`·캔버스/서피스/보더/텍스트/뱃지 색·radius(카드12/컨트롤8/칩6)·spacing. 원시 Tailwind 색(`blue-600` 등) 금지.
- **UX-DR2 (§1.5 성과 배수 색 밴드):** `performance_band_class` 헬퍼 — <2배 중립(muted) / 2~5배 `#15803D`bg`#E7F6EC` / 5~10배 `#0F7A38`bg`#C6EBD1` / >10배 흰텍스트 solid `#159C49`. amber/red 금지. FR-8·FR-11 전 화면 동일.
- **UX-DR3 (§2 타이포):** 폰트 스택 `Pretendard, "Noto Sans KR", "Noto Sans JP", system-ui`(한·일 글리프 동시 커버), 숫자 `tabular-nums`, §2.2 타입 스케일.
- **UX-DR4 (§4.1 좌측 내비):** 6항목(대시보드/인기 콘텐츠/경쟁 채널/콘텐츠 갭/저장한 영상/설정) + 활성 상태(primary) + 하단 데이터 범위 안내.
- **UX-DR5 (§4.2 추천 카드):** "이번 주 추천 콘텐츠 3개" 카드 컴포넌트 — 번호 뱃지·기회 점수·근거 보기 펼침.
- **UX-DR6 (§4.3 데이터 테이블):** `shared/_video_row` partial — 급상승 영상 테이블 행(성과 배수 히어로 셀·raw 조회수 뮤트 컬럼).
- **UX-DR7 (§4.4 뱃지/칩):** neutral/caution/danger 계열 + 영상 유형 배지(쇼츠/롱폼) + 구독자 밴드.
- **UX-DR8 (§4.5 경쟁 채널 동향 리스트):** 채널명·구독자·증감 리스트 컴포넌트.
- **UX-DR9 (§4.6 도넛·스파크라인):** 콘텐츠 기회 도넛 + 범례(4구간) + 7일 스파크라인 컴포넌트.
- **UX-DR10 (§4.7 정직성 상태):** 정직성 상태 컴포넌트 — 데이터 수집 중 / 측정한계 / 에버그린 후보 vs 검증 / 검증 요망 / 저신뢰. 위젯 숨김 금지, 자리 유지.
- **UX-DR11 (§4.8 컨트롤):** 버튼·기간 탭(활성 primary)·카테고리·유형 드롭다운·검색바.
- **UX-DR12 (§4.9 스켈레톤/로딩):** 로딩·스켈레톤 상태.
- **UX-DR13 (§5 반응형):** 좌측 내비 모바일 축소, 테이블 가로 스크롤(`overflow-x`), 본문 가로 스크롤 금지.
- **UX-DR14 (§7 다국어):** 제목·채널명 셀에 폰트 폴백·`word-break:keep-all`·line-clamp/truncate+`title` 툴팁·`min-w-0`·`lang` 힌트(한·일 혼재 제목 실데이터 오버플로 방어).
- **UX-DR15 (§9 라벨 정합·강제):** "구독자 대비 조회수" → "성과 배수(채널 평소 대비)" 전면 교체.
- **UX-DR16 (§8 Voice/Microcopy):** UI 문구를 §8 보이스 스펙 준수.

### FR Coverage Map

_파이프라인 제품 특성상 일부 FR은 계산(서비스/배치)과 표시(화면)가 다른 에픽에 걸친다. 아래는 **주 소재 에픽**과 분할을 명시한다._

- **FR-1** 일1회 자동 수집 → Epic 2
- **FR-2** uploads 경유 열거 → Epic 2
- **FR-3** 일별 스냅샷·롤업 → Epic 2
- **FR-4** 주1회 발굴 → Epic 2
- **FR-5** 성과 배수 계산 → Epic 3
- **FR-6** 신뢰도·플루크 방어 → Epic 3
- **FR-7** 성과·모멘텀 축 분리 → Epic 3 (VPD 값은 Out of Scope, 축 분리 원칙만)
- **FR-8** 통합 대시보드 뷰 → Epic 6
- **FR-9** 기간 전환 → Epic 6
- **FR-10** 구독자 밴드 티어링 → **Epic 3**(밴드·정렬 계산) + **Epic 6**(그룹핑 표시·평면 토글)
- **FR-11** 급상승 영상 테이블 → Epic 6
- **FR-12** 트렌드 스파크라인 → Epic 6 (콜드스타트 플레이스홀더, 값은 스냅샷 축적 후)
- **FR-13** 에버그린 후보(대리지표, 1일차) → Epic 3
- **FR-14** 에버그린 승격(검증) → **Epic 3**(스냅샷 스키마 자리만 유지, 값 계산 Out of Scope) + **Epic 6**(에버그린 탭에서 "검증=수집 중" 표시)
- **FR-15** 경쟁 채널 자동 추천 + 수동 등록/제외 → **Epic 2**(시드 로드·주1회 자동 발굴) + **Epic 6**(URL 수동 등록/제외 UI)
- **FR-16** 경쟁 채널 동향 → Epic 6
- **FR-17** 자사 유사영상 판정 → Epic 4
- **FR-18** 콘텐츠 갭 분포 → **Epic 4**(4구간 버킷 계산) + **Epic 6**(도넛 표시)
- **FR-19** 추천 주제 3개 → Epic 5
- **FR-20** 주제 자동 묶기 → Epic 4
- **FR-21** 기회 점수 산출 → Epic 5
- **FR-22** 조건부 구독자 증감 → **Epic 2**(channels.list 동승 스냅샷 수집) + **Epic 6**(조건부 표시·"측정한계", 소형 채널 값은 Out of Scope)
- **FR-23** 콜드 스타트 상태 표시 → Epic 6
- **FR-24** 시점 정합 편향 명시 → Epic 6
- **FR-25** 검색·필터·정렬 → Epic 7
- **FR-26** 영상 저장 → Epic 7

> **교차-에픽 불변식(AD-11):** `DailyCollectionJob`의 체인은 한 에픽에서 완성되지 않고 **Epic 2→3→4→5로 자라난다** — Epic 2가 잡 골격과 수집 스테이지를, Epic 3이 기준선/성과 배수/에버그린 후보 스테이지를, Epic 4가 임베딩/OwnVideoMatch/콘텐츠 갭/클러스터 스테이지를, Epic 5가 기회 점수/추천 스테이지를 순서대로 append한다. 각 스테이지는 이전 산출을 DB에서 읽어 다음 산출을 DB에 쓴다.

## Epic List

### Epic 1: 기반 · 인증 · 디자인 토큰 (Foundation)
운영 2인이 로그인해 앱 셸(좌측 내비 6항목 + 헤더)에 진입하고, 이후 모든 화면이 DESIGN.md 토큰으로 일관 렌더될 기반을 세운다. Rails 8 greenfield + SQLite 멀티DB(WAL) + 인증 제너레이터(2인 seed) + Tailwind v3 핀 + DESIGN.md §10 토큰 이관 + `config/scoring.yml` 자리 + 시크릿 격리.
**FRs covered:** (인프라 스타터 — AD-12/14/15/4 실현, FR-26 User 전제) / **표준:** AD-12, AD-14, AD-15, AD-4, AR-Secrets, UX-DR1·3·4·11
**Standalone:** 완결된 로그인 + 렌더 기반. 후속 에픽의 전제이나 후속에 의존하지 않음.

### Epic 2: 데이터 수집 파이프라인 (Collection)
밤사이 추적 채널의 영상 메타·조회수·구독자가 자동 수집·축적되어 스코어링·화면이 읽을 **원천 데이터**가 생긴다. 운영자는 수집 성공/실패/재시도 이력을 DB로 확인한다.
**FRs covered:** FR-1, FR-2, FR-3, FR-4, FR-15(시드·자동 발굴 부분), FR-22(스냅샷 수집 부분) / **표준:** AD-1, AD-5, AD-6, AD-8(is_short 캐시), AD-9(nil), AD-11(체인 골격·발굴 분리), AD-12, AD-13, AD-17(백업)
**Standalone:** 스코어링·화면 없이도 수집·스냅샷·관측·백업이 독립 동작.

### Epic 3: 성과 배수 스코어링 엔진 (Scoring)
각 영상이 "채널 평소 대비 몇 배" 성과인지 규모 편향 없이 판정된다 — **제품의 핵심 방법론**. 기준선(중앙값)·성과 배수·플루크 방어·에버그린 후보·밴드 티어링을 배치가 물질화한다.
**FRs covered:** FR-5, FR-6, FR-7, FR-13, FR-10(밴드 계산 부분), FR-14(스냅샷 스키마 자리만) / **표준:** AD-2, AD-3, AD-4, AD-8, AD-9, AD-16
**Standalone:** Epic 2의 스냅샷을 읽어 물질화 컬럼을 채운다. 화면 없이 값이 DB에 존재.

### Epic 4: 임베딩 · 자사 유사영상 · 콘텐츠 갭 (Similarity)
후보 주제를 자사가 이미 다뤘는지, 경쟁 대비 자사 커버리지 공백이 어디인지 판정된다. gemini 임베딩(제목 변경 시만 재생성) → OwnVideoMatch → 콘텐츠 갭 4구간 → 주제 클러스터.
**FRs covered:** FR-17, FR-18(버킷 계산), FR-20 / **표준:** AD-10, AD-3, AD-9
**Standalone:** Epic 2의 영상 + Epic 3와 병렬 가능(임베딩은 조회수 무관). 물질화된 매칭·갭·클러스터가 DB에 존재.

### Epic 5: 추천 주제 3개 · 기회 점수 (Recommendation — capstone)
MVP 최종 산출물 — 다음 주 제작할 **주제 3개**가 기회 점수·추천 이유·참고 경쟁 영상과 함께 산출된다(SM-2). 4입력 정규화 가중합, 자격 <3개면 정직 표시, 결정적 동점.
**FRs covered:** FR-19, FR-21 / **표준:** AD-2, AD-3, AD-4, AD-16
**Standalone:** Epic 3(성과 배수·최신성) + Epic 4(콘텐츠 갭·클러스터)를 읽어 `Recommendation` 스냅샷을 물질화.

### Epic 6: 대시보드 & 6화면 (Presentation)
운영자가 한 화면에서 추천·급상승·경쟁 채널·콘텐츠 갭·에버그린을 보고 **10분 안에 주제 3개를 결정**한다(SM-1). 공유 표시 컴포넌트(배수 셀·정직성 상태·테이블 행) 위에 6개 내비 화면을 얹는다.
**FRs covered:** FR-8, FR-9, FR-10(표시), FR-11, FR-12, FR-13(표시), FR-14(표시), FR-15(수동 등록/제외 UI), FR-16, FR-18(도넛), FR-22(조건부 표시), FR-23, FR-24 / **표준:** AD-15, AD-16, AD-7, UX-DR2·5~16
**Standalone:** Epic 3·4·5가 물질화한 값을 읽어 렌더. 모든 화면 스토리에 empty/loading/error·콜드스타트·정직성·다국어·반응형 AC 포함.

### Epic 7: 검색 · 필터 · 정렬 · 저장 (Explore & Save)
운영자가 키워드·채널·유형·기간·조회수·배수·구독자 밴드로 영상을 탐색·정렬하고, 관심 영상을 저장해 "저장한 영상" 화면에서 다시 본다.
**FRs covered:** FR-25, FR-26 / **표준:** AD-8(쇼츠/롱폼 필터 분리), AD-15, AD-14(SavedVideo·User)
**Standalone:** Epic 6의 화면·공유 행 위에 얹는 교차 기능. 독립 검증 가능.

---

## Epic 1: 기반 · 인증 · 디자인 토큰 (Foundation)

운영 2인이 로그인해 앱 셸에 진입하고, 이후 모든 화면이 DESIGN.md 토큰으로 일관 렌더될 기반을 세운다. 직접 FR은 적으나 AD-12/14/15/4 스타터가 후속 6개 에픽의 전제다.

### Story 1.1: Rails 8 앱 부트스트랩 + SQLite 멀티DB(WAL)

As a 개발자,
I want Rails 8 앱을 app/queue/cache 3개 SQLite 파일 + WAL로 세팅,
So that 배치 쓰기 중 웹 읽기가 논블로킹으로 동작한다.

**추적:** AD-12 / NFR-2 · **의존:** 없음(스타터)

**Acceptance Criteria:**

**Given** 빈 저장소에서
**When** Rails 8.x greenfield 앱을 생성하면
**Then** 언어는 Ruby다(Python·Node 백엔드 코드 없음)
**And** `config/database.yml`에 app·queue·cache 3개 SQLite 파일이 분리 정의된다
**And** WAL + `busy_timeout 5000ms`가 기본 적용된다
**And** Solid Queue·Solid Cache가 각 별도 DB 파일에 연결된다
**And** Redis 의존이 없다
**And** `bin/rails db:prepare`가 통과한다

### Story 1.2: 인증 제너레이터 + 운영 2인 seed

As a 운영자,
I want 로그인으로 앱 접근을 보호,
So that 미인증 접근이 차단된다.

**추적:** AD-14 / NFR-접근보호 · **의존:** 1.1

**Acceptance Criteria:**

**Given** `bin/rails generate authentication`이 실행된 상태에서
**When** 앱에 접근하면
**Then** `User`·세션·`has_secure_password`가 적용된다
**And** 운영 2인이 seed로 등록되어 있다(목업 아바타 2인과 정합)
**And** 미인증 요청은 로그인 화면으로 리다이렉트된다
**And** 외부 공개 회원가입 폼·멀티테넌시가 없다(내부 도구)

### Story 1.3: Tailwind v3 핀 + DESIGN.md §10 토큰 이관

As a 개발자,
I want DESIGN.md §10 토큰을 `config/tailwind.config.js` `theme.extend`로 이관,
So that 6화면이 색·간격·radius를 세션마다 재추정하지 않는다.

**추적:** AD-15 / UX-DR1·3 · **의존:** 1.1

**Acceptance Criteria:**

**Given** `tailwindcss-rails` 설치 시
**When** 버전을 고정하면
**Then** Tailwind는 **v3.x로 핀**된다(기본 4.x 방지, v4 `@theme` 미사용)
**And** `theme.extend`에 §10 토큰이 이관된다 — primary `#1145DD`·success `#159C49`·캔버스/서피스/보더/텍스트/뱃지 색·radius(카드12/컨트롤8/칩6)·spacing(4px 베이스)
**And** 폰트 스택 `Pretendard, "Noto Sans KR", "Noto Sans JP", system-ui`와 숫자 `tabular-nums`가 적용된다
**And** 원시 Tailwind 색(`blue-600` 등) 직접 사용이 금지되고 규칙이 문서화된다

### Story 1.4: 앱 셸 — 좌측 내비 + 헤더

As a 운영자,
I want 좌측 내비(6항목)와 헤더로 화면을 이동,
So that 어느 화면에 있는지 알고 이동한다.

**추적:** FR-11 IA(§11) / UX-DR4·11 · **의존:** 1.2, 1.3

**Acceptance Criteria:**

**Given** 로그인한 상태에서
**When** 앱 셸이 렌더되면
**Then** 좌측 내비에 6항목(대시보드/인기 콘텐츠/경쟁 채널/콘텐츠 갭/저장한 영상/설정)이 있고 활성 항목이 primary로 강조된다
**And** 내비 하단에 데이터 범위(YouTube 전체: 한국어+일본어 시장) 안내가 있다
**And** 헤더에 제목·부제("다음 주 제작할 주제를 10분 안에 결정하세요")·검색바 자리·"오늘 업데이트"·아바타 2인이 있다
**And** 모바일 화면에서 좌측 내비가 축소되고 본문이 가로로 깨지지 않는다
**And** 각 내비 항목은 빈 라우트로 연결된다(후속 에픽이 채운다)

### Story 1.5: `config/scoring.yml` 튜닝값 자리 + 시크릿 격리

As a 개발자,
I want 튜닝값을 단일 설정 파일로 격리,
So that 미확정 실측값을 코드 상수로 하드코딩하지 않는다.

**추적:** AD-4 / AR-Secrets · **의존:** 1.1

**Acceptance Criteria:**

**Given** 스코어링·표시 코드가 튜닝값을 필요로 할 때
**When** `config/scoring.yml`을 참조하면
**Then** AD-4 키 자리가 존재한다 — 기준선 N·유사도 τ·기회 점수 가중치와 정규화 매핑·에버그린 나이/배수 임계·조회수 하한(고정값·k)·구독자 규모 임계·극단배수(25x)·위젯별 전환 스냅샷 수·`is_short` duration 임계
**And** 값은 잠정 기본(PRD §13)이되 코드는 이 파일에서만 읽는다(상수 하드코딩 없음, 테스트가 회귀를 잡는다)
**And** API 키(YouTube·Gemini)는 Rails credentials 또는 ENV로만 두고 서비스 경계에서만 읽는다
**And** 리포·코드에 키 하드코딩이 없다(grep 검증)

---

## Epic 2: 데이터 수집 파이프라인 (Collection)

밤사이 추적 채널의 영상 메타·조회수·구독자가 자동 수집·축적되어 스코어링·화면이 읽을 원천 데이터가 생긴다. 운영자는 수집 성공/실패/재시도 이력을 DB로 확인한다.

### Story 2.1: Channel · Video 모델 + 시드 채널 로드

As a 운영자,
I want 시드 경쟁 채널이 초기 추적 대상으로 로드,
So that 1일차부터 수집 대상이 존재한다.

**추적:** FR-15(시드) / AR-Data-format · **의존:** 1.1

**Acceptance Criteria:**

**Given** 마이그레이션·seed 실행 시
**When** 모델이 생성되면
**Then** `Channel`(`youtube_channel_id`·`category` 4분류(직접경쟁/한국어교육일반/언어교육참고/상단퍼널)·`source`(seed/auto/manual)·`excluded`·`subscriber_count`·`uploads_playlist_id`)가 존재한다
**And** `Video`(`youtube_video_id`·`channel` 참조·`title`·`is_short`·`view_count`(nil 허용)·`duration`(초 정수)·`published_at`·`thumbnail`·`like_count`/`comment_count`(nil 허용))가 존재한다
**And** channel-analysis §5 시드가 `Channel(source: seed)`로 로드된다
**And** `excluded: true` 채널은 이후 수집·표시에서 제외된다

### Story 2.2: YouTube API 단일 클라이언트 경계 + 쿼터 원장

As a 개발자,
I want 모든 YouTube 호출을 `app/services/youtube` 경계로 통과,
So that 쿼터 회계·백오프·nil 방어가 한 곳에 모인다.

**추적:** FR-1(부분) / AD-1, AD-13 · **의존:** 1.5, 2.1

**Acceptance Criteria:**

**Given** YouTube Data API 호출이 필요할 때
**When** 어떤 호출부든
**Then** 호출은 오직 `app/services/youtube/*`를 통과한다(컨트롤러·모델·뷰·잡에서 `Net::HTTP`/SDK 직접 호출 없음, grep 검증)
**And** 이 경계가 단일 쿼터 원장으로 공유 1만 units 풀과 `search.list` 100콜/일 버킷을 각각 회계한다(재시도 소비 포함)
**And** 배치 크기 50이 이 경계 안에서만 관리된다
**And** 403(quota/rate) 실패는 지수 백오프로 재시도한다
**And** API 키는 credentials/ENV에서만 읽는다

### Story 2.3: uploads 경유 영상 열거 + `is_short` 불변 캐시

As a 운영자,
I want 채널 영상 메타·조회수를 정식 API로 열거,
So that 스크래핑 IP 차단 없이 수집한다.

**추적:** FR-2 / AD-8, AD-9 · **의존:** 2.2

**Acceptance Criteria:**

**Given** 추적 채널에 대해
**When** 열거를 실행하면
**Then** `channels.list`(uploads ID·구독자) → `playlistItems.list`(영상 ID) → `videos.list`(조회수·좋아요·댓글·길이·제목·썸네일·업로드일, 배치 50) 순으로 수집된다
**And** `likeCount`/`commentCount` 누락은 nil로 방어되어 파이프라인이 중단되지 않는다
**And** `duration`(ISO 8601)이 초 정수로 파싱 저장된다(원본 폐기)
**And** 좋아요·댓글은 수집·저장만 되고 채점·표시에 쓰이지 않는다
**And** `is_short`는 `Youtube::ClassifyShort`가 최초 저장 시 1회 duration 휴리스틱(임계는 `scoring.yml`)으로 판정·캐시하고 이후 불변이다(단일 writer)
**And** 회원 전용 영상은 `view_count` nil로 저장된다

### Story 2.4: 일별 스냅샷 축적 + 90일 롤업

As a 개발자,
I want 영상·채널 조회수/구독자를 일별 스냅샷으로 저장,
So that 모든 시계열 지표의 단일 원천이 된다.

**추적:** FR-3, FR-22(수집 부분) / AD-5, AD-6 · **의존:** 2.3

**Acceptance Criteria:**

**Given** 수집이 완료된 날
**When** 스냅샷을 저장하면
**Then** `VideoDailyStat(video, date, view_count)`·`ChannelDailyStat(channel, date, subscriber_count)`가 기록된다
**And** `(video_id, date)`·`(channel_id, date)`가 유니크라 같은 날 중복 행이 생기지 않는다
**And** `date`의 하루 경계는 `Asia/Tokyo`로 고정된다
**And** 구독자 스냅샷은 `channels.list`에 동승해 추가 API 비용이 0이다
**And** 최근 90일은 일단위로 유지되고 이후는 주단위로 롤업 후 원본 삭제 + `VACUUM`된다(일일 잡 동승)

### Story 2.5: DailyCollectionJob 체인 골격 + 관측성 + 백업

As a 운영자,
I want 하루 1회 자동 수집이 상시 스케줄러로 돌기,
So that 컴퓨터가 꺼져도 수집이 끊기지 않는다.

**추적:** FR-1 / AD-11(골격), AD-13, AD-17 · **의존:** 2.4

**Acceptance Criteria:**

**Given** Solid Queue recurring 스케줄에서
**When** `DailyCollectionJob`이 하루 1회 실행되면
**Then** 잡은 스테이지 체인 조립만 하고(channels→playlistItems→videos→스냅샷 저장) 로직은 서비스에 위임한다
**And** 서버 재시작 후에도 스케줄·잡 상태가 지속된다(DB 저장)
**And** 실행 이력(시작·성공·실패·재시도·쿼터 사용량)이 `job_runs` 테이블에 기록된다
**And** 실패는 지수 백오프로 재시도되고 재시도는 일1회 갱신 상한에 포함되지 않는다
**And** `app.sqlite3`(스냅샷 원천) 일일 백업 운영 절차가 정의된다(queue/cache DB 제외)

### Story 2.6: WeeklyDiscoveryJob — 주1회 신규 채널·영상 발굴

As a 운영자,
I want 시스템이 새 경쟁 채널을 자동 발굴,
So that 놓친 채널이 추적 대상에 추가된다.

**추적:** FR-4, FR-15(자동) / AD-11 · **의존:** 2.5

**Acceptance Criteria:**

**Given** 별도 Solid Queue recurring 스케줄에서
**When** `WeeklyDiscoveryJob`이 주 1회 실행되면
**Then** `search.list`를 하루 100콜 상한 안에서 사용해 키워드 기반 신규 채널·경쟁 영상 후보를 발굴한다
**And** 발굴된 채널은 `Channel(source: auto)`로 추가만 된다(채점은 일일 잡이 담당)
**And** 발굴은 일1회 갱신과 분리된 주기·별도 쿼터 버킷으로 동작한다

---

## Epic 3: 성과 배수 스코어링 엔진 (Scoring)

각 영상이 "채널 평소 대비 몇 배" 성과인지 규모 편향 없이 판정된다 — 제품의 핵심 방법론. 기준선·성과 배수·플루크 방어·에버그린 후보·밴드 티어링을 배치가 물질화하고, 스테이지를 `DailyCollectionJob` 체인에 append한다.

### Story 3.1: 기준선(중앙값) 계산 + 신뢰도 하한

As a 개발자,
I want 채널·유형별 기준선을 중앙값으로 계산,
So that 소수 대박 영상이 기준선을 오염시키지 않는다.

**추적:** FR-5, FR-6(신뢰도) / AD-2, AD-3, AD-8, AD-9 · **의존:** 2.4

**Acceptance Criteria:**

**Given** 채널의 공개 영상 표본에 대해
**When** `Scoring::CalculateBaseline`을 실행하면
**Then** 기준선은 채널·유형별 최근 N개(`scoring.yml`) 공개 영상 `view_count`의 **중앙값**이다(평균 아님)
**And** `Baseline(channel, video_type, median, sample_size, low_confidence)`로 물질화된다
**And** 쇼츠와 롱폼의 중앙값을 절대 공유하지 않는다
**And** 회원 전용(nil) 영상은 표본에서 제외된다
**And** 유형별 최근 공개 영상이 10개 미만이면 `low_confidence` 플래그가 붙는다
**And** 자사 실측 200~4,100 픽스처로 중앙값 계산·유형 미공유·nil 제외가 검증된다

### Story 3.2: 성과 배수 계산 + 플루크 방어 + 축 분리

As a 운영자,
I want 각 영상의 성과 배수를 채널 평소 대비로 계산,
So that 규모가 다른 채널을 공정하게 비교한다.

**추적:** FR-5, FR-6, FR-7 / AD-2, AD-3 · **의존:** 3.1

**Acceptance Criteria:**

**Given** 기준선이 물질화된 영상에 대해
**When** 성과 배수를 계산하면
**Then** 성과 배수 = 현재 누적 `view_count` ÷ 채널·유형 기준선으로 배치 물질화된다(웹 요청 경로 재계산 없음)
**And** 조회수 하한(기준선 상대식 `max(고정값, k × 기준선)`, `scoring.yml`) 미만 영상은 배수 순위에서 기본 제외된다(고정 절대값 일괄 적용 금지)
**And** 성과 배수가 25배를 초과하면 "검증 요망 — 외부 요인 가능" 플래그가 붙는다
**And** 성과 배수(성과)와 VPD(모멘텀)를 하나의 종합 점수로 합산하는 코드 경로가 없다(별도 축, 테스트로 검증)
**And** 픽스처로 조회수 하한 상대식·극단배수 상한·nil 제외 동작이 검증된다

### Story 3.3: 구독자 밴드 티어링 + 결정적 정렬키

As a 운영자,
I want 결과가 구독자 밴드로 그룹핑되고 밴드 내 배수로 정렬,
So that 소형 채널의 대박이 자기 슬롯에서 드러난다.

**추적:** FR-10(계산) / AD-2, AD-15 · **의존:** 3.2

**Acceptance Criteria:**

**Given** 성과 배수가 계산된 영상들에 대해
**When** 밴드·정렬을 산출하면
**Then** 구독자 밴드 4티어(<1만/1만~10만/10만~50만/50만+)가 계산된다(밴드는 필터·그룹핑 축이지 배수 분모가 아님)
**And** 기본 정렬키는 성과 배수 내림차순이다(raw 조회수 기본 정렬 금지)
**And** 표시·평면 토글은 Epic 6이 담당한다

### Story 3.4: 에버그린 후보 판정(대리지표, 1일차)

As a 운영자,
I want 오래됐는데 배수 높은 영상을 에버그린 후보로 표시,
So that 검색 유입형 주제를 1일차부터 발견한다.

**추적:** FR-13, FR-14(자리만) / AD-2, AD-4, AD-16 · **의존:** 3.2

**Acceptance Criteria:**

**Given** 기준선·성과 배수가 계산된 영상에 대해
**When** 에버그린 후보를 판정하면
**Then** 두 임계가 동시 충족돼야 한다 — 나이(경과일 ≥ 기준일) AND 성과 배수(≥ 임계, `scoring.yml`) — 배수>1을 후보 기준으로 쓰지 않는다
**And** 판정된 영상은 "에버그린 후보"로 라벨링되고 "에버그린"으로 단정하지 않는다
**And** 후보 판정은 스냅샷 없이 현재 조회수·업로드일·기준선만으로 계산된다(1일차 동작, FR-5 증폭 편향 상속 주석)
**And** 검증 승격(FR-14)의 값은 계산하지 않고 `VideoDailyStat` 스키마가 미래 소재지로 자리만 유지한다(MVP Out of Scope)

---

## Epic 4: 임베딩 · 자사 유사영상 · 콘텐츠 갭 (Similarity)

후보 주제를 자사가 이미 다뤘는지, 경쟁 대비 자사 커버리지 공백이 어디인지 판정된다. 임베딩은 조회수와 무관하므로 Epic 3과 병렬 진행 가능하다. 스테이지를 `DailyCollectionJob` 체인에 append한다.

### Story 4.1: 임베딩 생성·저장 (제목 변경 시만 재생성)

As a 개발자,
I want 영상 제목 임베딩을 BLOB로 저장,
So that 유사영상 판정·주제 묶기 인프라를 확보한다.

**추적:** FR-17(임베딩), FR-20(인프라) / AD-10 · **의존:** 2.3, 1.5

**Acceptance Criteria:**

**Given** 신규 또는 제목 변경 영상에 대해
**When** `Embedding::UpsertVectors`를 실행하면
**Then** `videos`의 packed-float BLOB 컬럼에 임베딩이 저장되고 `embedding_source_hash`(제목 기준)가 함께 저장된다
**And** `gemini-embedding-001`(유료, credentials 키)로 신규 영상 + `embedding_source_hash`가 바뀐 행만 재생성된다(과금은 여기에만)
**And** Gemini 호출은 서비스 경계에서만 난다
**And** sqlite-vec는 채택하지 않는다(BLOB + Ruby 코사인)

### Story 4.2: 자사 유사영상 판정 (OwnVideoMatch)

As a 운영자,
I want 경쟁 영상마다 자사 유사영상 유무를 판정,
So that 이미 다룬 주제인지 확인한다.

**추적:** FR-17 / AD-10, AD-3, AD-9 · **의존:** 4.1

**Acceptance Criteria:**

**Given** 임베딩이 있는 경쟁·자사 영상에 대해
**When** 배치가 유사도를 계산하면
**Then** `OwnVideoMatch(competitor_video_id, own_video_id, similarity)`가 물질화된다(웹 요청 경로 아님)
**And** 유사도는 메모리로 올린 BLOB에 Ruby 코사인으로 계산된다
**And** 임계 τ는 `scoring.yml`에서 읽는다(고정 0.8 맹신 금지)
**And** 코스(회원 전용) 자사 영상은 매칭 결과에 나오되 성과 수치는 표시되지 않는다

### Story 4.3: 콘텐츠 갭 4구간 버킷

As a 운영자,
I want 자사 커버리지를 4구간으로 분류,
So that 어디에 콘텐츠 공백이 있는지 파악한다.

**추적:** FR-18(계산) / AD-3, AD-10 · **의존:** 4.2

**Acceptance Criteria:**

**Given** `OwnVideoMatch`가 물질화된 경쟁 영상에 대해
**When** 콘텐츠 갭을 분류하면
**Then** 각 경쟁 영상이 미제작 / 유사영상 1개 / 유사영상 2개+ / 포화 4구간으로 분류·물질화된다
**And** 이 분류는 급상승 영상 행의 자사 유사영상 컬럼과 일치한다(Epic 6 표시가 참조)

### Story 4.4: 임베딩 기반 주제 자동 묶기 (연결요소)

As a 개발자,
I want 영상을 주제 단위로 자동 묶기,
So that 추천이 개별 영상이 아니라 주제로 묶인다.

**추적:** FR-20 / AD-10 · **의존:** 4.1

**Acceptance Criteria:**

**Given** 임베딩이 있는 영상들에 대해
**When** 주제 묶기를 실행하면
**Then** 코사인 유사도 ≥ τ(FR-17 재사용) 영상 쌍을 간선으로 잇고 연결 요소(connected components)를 하나의 `TopicCluster`로 본다
**And** 묶기는 스냅샷이 아니라 임베딩에 의존해 1일차부터 동작한다
**And** 추가 임베딩 비용이 발생하지 않는다(같은 인프라 재사용)
**And** `TopicCluster`는 배치마다 재계산되는 휘발성이다(`relatedToVideoId` 미사용)

---

## Epic 5: 추천 주제 3개 · 기회 점수 (Recommendation — capstone)

MVP 최종 산출물 — 다음 주 제작할 주제 3개가 기회 점수·근거·참고 영상과 함께 산출된다(SM-2). Epic 3(성과 배수·최신성) + Epic 4(콘텐츠 갭·클러스터)를 읽어 물질화하고, 체인의 마지막 스테이지를 append한다.

### Story 5.1: 기회 점수 산출 (4입력 정규화 가중합)

As a 운영자,
I want 주제를 기회 점수로 랭킹,
So that 제작 우선순위를 판단한다.

**추적:** FR-21 / AD-2, AD-3, AD-4 · **의존:** 3.2, 4.3, 4.4

**Acceptance Criteria:**

**Given** 성과 배수·콘텐츠 갭·주제 클러스터가 물질화된 상태에서
**When** 기회 점수를 산출하면
**Then** 4입력(성과 배수 신호·경쟁 공통성·콘텐츠 갭·최신성)이 각각 [0,1]로 정규화되고 가중합 후 ×100 된다
**And** 정규화 매핑과 가중치는 `scoring.yml`에서 읽는다(구조는 불변, 값만 설정)
**And** 기회 점수는 성과 배수 하나로 대체되지 않는 별도 종합 지표다
**And** 점수가 배치 물질화된다

### Story 5.2: 추천 주제 3개 산출 + 정직성 + 결정적 동점

As a 운영자,
I want 다음 주 주제 3개를 근거와 함께 받기,
So that 10분 안에 제작 주제를 결정한다.

**추적:** FR-19 / AD-2, AD-10, AD-16 · **의존:** 5.1

**Acceptance Criteria:**

**Given** 기회 점수가 산출된 주제 클러스터에 대해
**When** 추천 3개를 생성하면
**Then** `Recommendation(reference_video_ids, topic_label, opportunity_score)`이 생성 시점 스냅샷으로 저장된다(휘발 `TopicCluster`에 FK 금지)
**And** 각 추천은 주제명·추천 이유·참고 경쟁 영상(제목·썸네일·채널·조회수·URL)·자사 유사영상 유무·기회 점수를 포함한다
**And** 자격 주제가 3개 미만이면 억지로 만들지 않고 "이번 주 N개 확보"로 정직하게 표시한다
**And** 동점 처리는 결정적이다 — 기회 점수 → 성과 배수 → 최신성 순(픽스처로 검증)
**And** 이 스테이지가 `DailyCollectionJob` 체인의 마지막에 append된다

---

## Epic 6: 대시보드 & 6화면 (Presentation)

운영자가 한 화면에서 추천·급상승·경쟁 채널·콘텐츠 갭·에버그린을 보고 10분 안에 주제 3개를 결정한다(SM-1). 공유 표시 컴포넌트 위에 6개 내비 화면을 얹는다. **모든 화면 스토리는 empty/loading/error·콜드스타트·정직성·다국어·반응형 AC를 포함한다.**

### Story 6.1: 공유 표시 컴포넌트 (배수 셀 · 정직성 상태 · 테이블 행 · 헬퍼)

As a 개발자,
I want 공유 위젯을 partial + helper로 캡슐화,
So that 6화면이 배수 표시·정직성 상태를 일관되게 렌더한다.

**추적:** FR-8, FR-11, FR-24 / AD-15, AD-16 · **의존:** 3.2, 5.2, 1.3

**Acceptance Criteria:**

**Given** 물질화된 스코어링 값이 있을 때
**When** 공유 컴포넌트를 렌더하면
**Then** `shared/_performance_cell`이 성과 배수를 히어로 셀·색 밴드로, raw 조회수를 2차 뮤트 컬럼으로 표시한다
**And** `performance_band_class` 헬퍼가 §1.5 순차 그린 램프를 매핑한다(<2배 중립 / 2~5배 / 5~10배 / >10배 solid, amber·red 금지)
**And** `shared/_video_row`가 썸네일·제목·채널·업로드일·조회수·배수·자사 유사영상·유형 배지·구독자 밴드를 담는다
**And** `shared/_honesty_status`가 5상태(데이터 수집 중/측정한계/후보 vs 검증/검증 요망/저신뢰)를 §4.7 스타일로 표시한다(위젯 숨김 없이 자리 유지)
**And** 제목·채널명 셀에 폰트 폴백·`word-break:keep-all`·line-clamp/truncate+`title` 툴팁·`min-w-0`·`lang` 힌트가 적용된다(한·일 혼재 오버플로 방어)
**And** "구독자 대비 조회수" 표현이 어디에도 없고 "성과 배수(채널 평소 대비)"로 통일된다
**And** 성과 배수 옆/툴팁에 두 편향 기전이 모두 명명된다 — (1) 누적 조회수 사용, (2) 최근 N개 젊은 기준선

### Story 6.2: 대시보드 홈 — 추천 3개 + 기간 탭 + 필터 바

As a 운영자,
I want 대시보드 홈에서 추천 3개·기간 탭·필터를 보기,
So that 한 화면에서 이번 주를 훑는다.

**추적:** FR-8, FR-9, FR-10(표시), FR-19(표시), FR-23 / AD-7, AD-15 · **의존:** 6.1

**Acceptance Criteria:**

**Given** 물질화된 추천·배수 값이 있을 때
**When** 대시보드 홈을 열면
**Then** 상단에 "이번 주 추천 콘텐츠 3개" 카드(번호 뱃지·기회 점수·근거 보기 펼침)가 표시된다
**And** 기간 탭(최근 1주/1개월/3개월)이 업로드 기간 필터로 동작하고(콜드스타트에서도 동작) 에버그린 탭이 있다
**And** 카테고리·유형 드롭다운(한국어 교육/영어 교육/일반 영상 + Shorts)이 있다
**And** 기본 레이아웃이 구독자 밴드 그룹핑 + 밴드 내 배수 정렬이고 평면 토글이 가능하다
**And** empty(추천 0개 → "N개 확보")·loading(스켈레톤)·error 상태가 각각 표시된다
**And** 시계열 위젯은 위젯별 준비도로 "D+n 데이터 수집 중"을 개별 표시한다(전역 배너 금지)
**And** 모바일에서 레이아웃이 깨지지 않고 본문 가로 스크롤이 없다

### Story 6.3: 인기 콘텐츠 — 급상승 영상 테이블 + 스파크라인

As a 운영자,
I want 급상승 영상 테이블에서 배수 상위 영상을 보기,
So that 성과 높은 콘텐츠를 탐색한다.

**추적:** FR-11, FR-12 / AD-15, AD-7 · **의존:** 6.1

**Acceptance Criteria:**

**Given** 물질화된 배수·유사영상 값이 있을 때
**When** 인기 콘텐츠 화면을 열면
**Then** 테이블 컬럼이 순번/영상(썸네일+제목)/채널/업로드일/조회수/성과 배수/트렌드(7일 스파크라인)/자사 유사영상이다
**And** 배수가 색 밴드로 강조되고 raw 조회수는 뮤트 컬럼이며 유형 배지·구독자 밴드·주제 힌트가 표시된다
**And** 영상 클릭 시 유튜브 URL로 이동한다
**And** 스파크라인은 시계열 의존이라 콜드스타트에 "데이터 수집 중" 플레이스홀더로 자리를 유지한다
**And** 테이블이 좁은 화면에서 가로 스크롤되고 본문은 가로로 깨지지 않는다
**And** empty·loading·error 상태와 다국어 제목 말줄임이 처리된다

### Story 6.4: 경쟁 채널 화면 — 동향 + 수동 등록/제외 + 구독자 증감

As a 운영자,
I want 경쟁 채널 동향을 보고 URL로 등록/제외,
So that 추적 대상을 직접 관리한다.

**추적:** FR-15(UI), FR-16, FR-22(표시) / AD-5, AD-7, AD-16 · **의존:** 6.1, 2.6

**Acceptance Criteria:**

**Given** 추적 채널 목록이 있을 때
**When** 경쟁 채널 화면을 열면
**Then** 채널명·구독자·(조건부)구독자 증감 리스트가 표시된다
**And** 채널 URL 입력 시 `Channel(source: manual)`로 추가되어 다음 수집 주기부터 반영된다
**And** 제외한 채널은 대시보드·채점에서 빠진다
**And** 구독자 증감은 7일 스냅샷 후 규모 임계(`scoring.yml`) 이상 채널만 표시되고 미만은 "측정한계" 라벨이 붙는다(소형 채널 값은 Out of Scope)
**And** empty(채널 0)·loading·error 상태와 콜드스타트("D+7 수집 중")가 표시된다
**And** 반응형·다국어 오버플로가 처리된다

### Story 6.5: 콘텐츠 갭 화면 — 도넛 분포

As a 운영자,
I want 콘텐츠 갭 4구간 분포를 보기,
So that 미제작 주제를 파악한다.

**추적:** FR-18(표시) / AD-7, AD-16 · **의존:** 6.1, 4.3

**Acceptance Criteria:**

**Given** 콘텐츠 갭이 물질화된 상태에서
**When** 콘텐츠 갭 화면을 열면
**Then** 콘텐츠 기회 도넛과 범례가 4구간 비율·건수를 표시한다
**And** 각 행의 자사 유사영상 컬럼과 도넛 분류가 일치한다
**And** empty(경쟁 영상 0)·loading·error 상태가 표시된다
**And** 임베딩 미완 시 "준비 중"으로 자리를 유지한다
**And** 반응형·다국어가 처리된다

### Story 6.6: 에버그린 화면 — 후보 표시 + 검증 "수집 중"

As a 운영자,
I want 에버그린 후보와 검증을 구분해 보기,
So that 검색 유입형 주제를 발견한다.

**추적:** FR-13(표시), FR-14(표시) / AD-16 · **의존:** 6.1, 3.4

**Acceptance Criteria:**

**Given** 에버그린 후보가 물질화된 상태에서
**When** 에버그린 탭/화면을 열면
**Then** 후보가 "에버그린 후보" 라벨로 1일차부터 표시된다
**And** 검증 에버그린은 "데이터 수집 중"으로 자리를 유지한다(스냅샷 축적 후 값, MVP Out of Scope)
**And** 후보와 검증이 시각적으로 구분된다
**And** empty·loading·error 상태와 반응형·다국어가 처리된다

### Story 6.7: 설정 화면 — 수집 상태 + 계정

As a 운영자,
I want 수집 잡 상태와 계정을 관리,
So that 수집 실패를 확인하고 로그아웃한다.

**추적:** IA(§11 설정) / AD-13(UI 표면) · **의존:** 6.1, 2.5

**Acceptance Criteria:**

**Given** `job_runs` 이력이 쌓인 상태에서
**When** 설정 화면을 열면
**Then** 최근 수집 이력(성공/실패/재시도/쿼터 사용량)이 표시된다
**And** 데이터 범위·백업 상태 안내와 계정(로그아웃)이 있다
**And** empty·error 상태와 반응형이 처리된다

---

## Epic 7: 검색 · 필터 · 정렬 · 저장 (Explore & Save)

Epic 6의 화면·공유 행 위에 얹는 교차 기능. 운영자가 영상을 탐색·정렬하고 관심 영상을 저장한다.

### Story 7.1: 검색 · 필터 · 정렬

As a 운영자,
I want 키워드·채널·유형·기간·조회수·배수·밴드로 영상을 검색·정렬,
So that 원하는 영상을 빠르게 찾는다.

**추적:** FR-25 / AD-3, AD-8, AD-15 · **의존:** 6.3

**Acceptance Criteria:**

**Given** 물질화된 영상·배수 값이 있을 때
**When** 검색·필터·정렬을 적용하면
**Then** 키워드·채널·영상 유형·업로드 기간·조회수·성과 배수·구독자 밴드로 필터·정렬된다
**And** 성과 배수 임계 프리셋(2x/3x/5x/10x/25x)이 제공된다
**And** 쇼츠/롱폼이 필터 차원에서 분리 유지된다
**And** 필터는 물질화 컬럼을 쿼리하고 웹 요청 경로에서 재계산하지 않는다(P95 2초)
**And** 결과 0건 empty·loading 상태와 반응형이 처리된다

### Story 7.2: 영상 저장 + 저장한 영상 화면

As a 운영자,
I want 관심 영상을 저장하고 다시 보기,
So that 참고 영상을 모아 다음 제작에 쓴다.

**추적:** FR-26 / AD-14 · **의존:** 6.1, 1.2

**Acceptance Criteria:**

**Given** 로그인한 사용자가 영상을 볼 때
**When** 저장 버튼을 누르면
**Then** `SavedVideo(user, video)`가 생성되고 토글로 해제된다
**And** "저장한 영상" 내비 화면에서 저장 목록을 재열람한다(사용자별)
**And** empty("저장한 영상 없음")·loading 상태와 반응형·다국어가 처리된다
