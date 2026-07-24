---
title: 'Story 6.4: 경쟁 채널 화면 — 동향 + 수동 등록/제외 + 구독자 증감'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 1
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-6-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-1-shared-display-components.md'
  - '{project-root}/_bmad-output/implementation-artifacts/spec-6-3-popular-videos-table.md'
  - '{project-root}/DESIGN.md'
warnings: []
baseline_revision: 'd216cfd1c23acb6f03e4668fbbd50bc3b09fe334'
final_revision: ''
---

<intent-contract>

## Intent

**Problem:** 경쟁 채널 화면이 placeholder다. 운영자가 경쟁 채널 동향(구독자·구독자 증감)을 훑고, 새 경쟁 채널을 수동 등록하거나 관심 밖 채널을 제외할 수단이 없다.

**Approach:** `CompetitorsController`가 **읽기 전용 index**(AD-3, 물질화·저장 스냅샷 읽기만)로 `Channel.competitor`(is_own:false) 동향 리스트(DESIGN §4.5)를 렌더한다 — 아바타·채널명·구독자·구독자 증감(ChannelDailyStat 7일 델타). 구독자 증감은 §4.7 정직성 3상태(데이터 수집 중 / 측정한계 / 표시). **수동 등록·제외는 별도 쓰기 액션**(create·toggle_exclusion) — 등록 시 채널 메타는 YouTube 스텁 경계 경유(실 호출 보류, 키 대기), 제외는 `excluded` 불리언 토글. DESIGN §10 토큰만.

## Boundaries & Constraints

**Always:**
- **index 는 읽기 전용**(AD-3) — `Channel.competitor`(is_own:false)를 `includes(:daily_stats)`로 로드해 필터·정렬만. 구독자 증감은 저장된 `ChannelDailyStat.subscriber_count` 시계열 **읽기**(재계산·API 호출 금지). 자사 채널(is_own:true)은 경쟁 목록에서 제외.
- **구독자 증감 정직성 3상태**(§4.7) — (1) 스냅샷 수 < `cold_start_snapshots.subscriber_delta`(7) → "데이터 수집 중"(dashed, D+n). (2) `|증감%|` < `subscriber_delta.min_material_pct`(scoring.yml) → "측정한계" neutral 칩. (3) 그 외 → §4.5 미니 진행 바(증가 `success-600` 채움+퍼센트 / 감소 `text-ink-muted` + ↓). 증감% = `(latest−earliest)/earliest×100`(7일 창). 위젯 숨김 금지·자리 유지.
- **동향 리스트 = DESIGN §4.5 그대로** — 각 행: 원형 이니셜 아바타(radius-full, §10 파스텔 배경 토큰 + 진한 글자, 채널별 결정적) + 채널명(text-body truncate·min-w-0·break-keep·title, §7 다국어) + 구독자(text-ink-muted tabular, nil→"미상") + 구독자 증감. **대표 영상/성과 컬럼 없음**(§4.5 미정의 — 임의 추가 금지).
- **수동 등록(create, 쓰기)** — 폼: 채널 URL/ID + 채널명 + 카테고리(Channel::CATEGORIES). 입력에서 youtube_channel_id 파싱(`/channel/UC…` 또는 raw UC…). 채널 메타(subscriber_count·uploads_playlist) 는 `Youtube::Client#list_channels([id])`(스텁 경계, 실 호출 보류 — 스텁이 "아직 진짜 아님" 로그). `Channel.create!(source:"manual", is_own:false, category:, name:, youtube_channel_id:, subscriber_count:, uploads_playlist_id:)`. 다음 수집 주기가 daily_stats 축적(§42). 중복(youtube_channel_id 유니크)·유효성 오류는 flash 로 안전 처리, 500 금지.
- **제외 토글(toggle_exclusion, 쓰기)** — `excluded` 불리언 flip. 제외 채널은 대시보드·수집·채점에서 빠짐(기존 not_excluded 스코프). 화면은 활성 경쟁 리스트 + "제외된 채널" 접기 섹션(복원 가능).
- 색·간격 **DESIGN §10 토큰만**(원시 색 금지, AD-15). 아바타 파스텔은 §10 badge/surface 계열 토큰에서 결정적 선택. 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**. 상태 문구 Glossary 그대로("데이터 수집 중"·"측정한계").
- 반응형(§5): 리스트/폼 모바일 스택, 넓은 표 요소는 `overflow-x-auto`, **본문 가로 스크롤 금지**. empty(경쟁 0)·loading(스켈레톤)·error 상태. nil 방어(AD-9).
- 쓰기 액션은 인증(Authentication) + CSRF(기본) 뒤. index 는 GET.

**Block If:**
- (없음 — §4.5·§4.7·운영자 결정[측정한계=증감폭 상대비율]로 확정. 신규 디자인이면 운영자 문의.)

**Never:**
- 웹 요청 경로에서 구독자 증감/성과 재계산(저장 스냅샷 읽기만). index 에서 YouTube API 호출. 실 YouTube 라이브 호출(키 대기 — 스텁 경계만, mode 기본 stub). 원시 Tailwind 색. "구독자 대비 조회수". 자사 채널을 경쟁 목록에 노출. §4.5 없는 컬럼(대표 영상 등) 임의 추가. 값 없다고 증감 위젯 숨김.
- 컨트롤러 index 에 계산 로직. 콘텐츠 갭·에버그린·설정(6.5~6.7) 기능.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 경쟁만 | is_own=false | 경쟁 채널만, 자사 제외 | — |
| 정렬 | 경쟁 리스트 | 구독자수 desc, nil 마지막 | — |
| 증감 콜드 | 스냅샷<7 | "데이터 수집 중"(D+n, dashed) | AD-7 |
| 증감 측정한계 | \|증감%\|<임계 | "측정한계" neutral 칩 | — |
| 증감 표시(증가) | \|증감%\|≥임계, +방향 | success-600 바 + 퍼센트 | — |
| 증감 표시(감소) | ≥임계, −방향 | ink-muted + ↓ 퍼센트 | — |
| 구독자 미상 | subscriber_count nil | "미상" | AD-9 |
| 수동 등록 | URL+명+카테고리 | Channel(source:manual,is_own:false) 생성, 스텁 메타 | 유효성→flash |
| 등록 중복 | 기존 youtube_channel_id | 생성 안 함, flash 안내 | RecordNotUnique 흡수 |
| 등록 URL 파싱 실패 | 잘못된 URL | flash 오류, 생성 안 함 | — |
| 제외 토글 | 채널 행 "제외" | excluded=true, 리스트에서 활성 제외 | — |
| 복원 | 제외 섹션 "복원" | excluded=false | — |
| 읽기 전용 | GET /competitors | Channel 쓰기 없음 | — |
| empty | 경쟁 0 | empty 상태 + 등록 폼 | — |
| 모바일 | 좁은 뷰포트 | 리스트/폼 스택, 본문 스크롤 없음 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 아바타 | 채널명 | 첫 글자 이니셜 + 결정적 파스텔 | 이름 없음→"?" |

</intent-contract>

## Code Map

- `config/routes.rb` -- `post "competitors"`(create)·`patch "competitors/:id/exclusion"`(toggle) 추가(기존 get 유지)
- `app/controllers/competitors_controller.rb` -- `#index`(읽기 전용, 경쟁 로드/정렬/프리로드)·`#create`(수동 등록, 스텁 메타)·`#toggle_exclusion`(excluded flip)
- `app/services/youtube/register_channel.rb` -- (신규) URL/ID 파싱 + `Youtube::Client#list_channels` 스텁 메타 조회 + `Channel.create!` (실 호출 보류·스텁 마킹). 쓰기 경계 분리.
- `app/helpers/competitors_helper.rb` -- (신규) `subscriber_delta_state(channel)`(daily_stats 읽기 → {state, pct, days})·`avatar_style(name)`(결정적 파스텔 §10)·`avatar_initial(name)`
- `app/views/competitors/index.html.erb` -- placeholder 교체: 등록 폼 + §4.5 동향 리스트 + 제외 섹션 + empty/loading/error
- `app/views/competitors/_channel_row.html.erb` -- §4.5 행(아바타·명·구독자·증감 위젯)
- `app/views/competitors/_subscriber_delta.html.erb` -- 증감 3상태 위젯(진행 바 / 측정한계 / 데이터 수집 중)
- `config/scoring.yml` -- `subscriber_delta.min_material_pct`·`bar_full_pct`(추가 완료)
- `test/controllers/competitors_controller_test.rb`·`test/helpers/competitors_helper_test.rb` -- 200·읽기 전용·경쟁만·정렬·증감 3상태·등록(스텁·중복·파싱)·제외 토글·라벨/색 금지·N+1

## Tasks & Acceptance

**Execution:**
- [ ] `config/routes.rb` -- `post "competitors" => "competitors#create"`; `patch "competitors/:id/exclusion" => "competitors#toggle_exclusion", as: :competitor_exclusion` (기존 `get "competitors"` 유지) -- 라우트 AC
- [ ] `app/helpers/competitors_helper.rb` -- `subscriber_delta_state(channel)`: 프리로드 `daily_stats` date asc → size < `Scoring::Config.fetch(:cold_start_snapshots, :subscriber_delta)`면 `{state: :collecting, days: size}`; earliest.subscriber_count·latest.subscriber_count 로 `pct=(l−e)/e*100`(e 0/nil 방어); `|pct| < Scoring::Config.fetch(:subscriber_delta, :min_material_pct)`면 `{state: :immaterial}`; else `{state: :material, pct:, direction:}`. `avatar_initial(name)`(첫 grapheme, 없으면 "?"); `avatar_style(name)`(name 해시 → §10 파스텔 bg/fg 쌍 결정적). 전부 읽기만 -- 헬퍼 AC
- [ ] `app/services/youtube/register_channel.rb` -- `RegisterChannel.new(client:).call(url_or_id:, name:, category:)`: `parse_channel_id`(`/channel/UC…`|raw `UC…`, 실패 nil→ArgumentError); `items = client.list_channels([id])`(스텁 경계); item.statistics.subscriberCount·contentDetails.relatedPlaylists.uploads 추출(nil 방어); `Channel.create!(source:"manual", is_own:false, category:, name: name.presence, youtube_channel_id: id, subscriber_count:, uploads_playlist_id:)`. 실 호출 보류(mode 기본 stub — 스텁이 "아직 진짜 아님" 로그). 중복은 호출부가 rescue -- 등록 경계 AC
- [ ] `app/controllers/competitors_controller.rb` -- `#index`: `@active = Channel.competitor.not_excluded.includes(:daily_stats).order(Arel.sql("subscriber_count DESC NULLS LAST"))`; `@excluded = Channel.competitor.where(excluded: true).includes(:daily_stats)`. **계산 없음**. `#create`: `RegisterChannel.new.call(...)` → notice; rescue(ArgumentError·RecordInvalid·RecordNotUnique) → alert; redirect_to competitors_path. `#toggle_exclusion`: `Channel.competitor.find(params[:id]).update!(excluded: ...)`; redirect -- 컨트롤러 AC
- [ ] `app/views/competitors/index.html.erb`·`_channel_row.html.erb`·`_subscriber_delta.html.erb` -- placeholder 교체: 등록 폼(form_with url: competitors_path, method:post — URL·명·카테고리 select) → §4.5 동향 리스트(활성) → "제외된 채널" disclosure(복원 button_to patch) → empty/loading/error. DESIGN §10 토큰만, §7 다국어, §5 반응형 -- 화면 AC
- [ ] `test/controllers/competitors_controller_test.rb`·`test/helpers/competitors_helper_test.rb` -- 200·GET 읽기 전용(Channel.count 불변)·경쟁만(자사 부재)·구독자 desc nulls last·증감 콜드/측정한계/표시(증가·감소)·등록(source:manual 생성·중복 흡수·URL 파싱 실패 flash)·제외 토글·복원·"구독자 대비 조회수" 부재·원시 색 부재·N+1(daily_stats 프리로드) -- 검증

**Acceptance Criteria:**
- Given 물질화된 경쟁 채널·구독자 스냅샷, when 경쟁 채널 화면을 열면, then §4.5 동향 리스트(아바타·채널명·구독자·구독자 증감)가 렌더되고 자사 채널은 빠진다.
- Given 구독자 스냅샷 수, when 7 미만이면 "데이터 수집 중", when |증감%|가 임계 미만이면 "측정한계", when 그 이상이면 진행 바/퍼센트로, then 위젯 자리를 유지한 채 정직성 상태가 표시된다.
- Given 채널 URL·명·카테고리, when 수동 등록하면, then Channel(source:manual, is_own:false)이 생성되고 메타는 스텁 경계로 채워지며(실 호출 보류) 다음 수집 주기가 스냅샷을 축적한다. 중복·잘못된 URL 은 flash 로 안전 처리된다.
- Given 채널 행, when "제외"하면, then excluded=true 로 활성 리스트에서 빠지고 대시보드·채점에서도 제외되며, "제외된 채널"에서 복원할 수 있다.
- Given GET /competitors, when 요청하면, then Channel 을 쓰지 않는다(읽기 전용, AD-3).
- Given 좁은 화면, when 보면, then 리스트·폼이 스택되고 본문은 가로로 깨지지 않으며 다국어 채널명이 말줄임된다.

## Design Notes

**구독자 증감 = 저장 스냅샷 읽기(AD-3).** `ChannelDailyStat.subscriber_count` 7일 창을 헬퍼가 읽어 퍼센트만 산출 — 웹 요청 경로 재계산 아님(순수 표시 변환). 3상태는 §4.7 정직성: 콜드(<7 스냅샷)=데이터 수집 중, 저材料(|%|<임계)=측정한계, 그 외=진행 바. 임계는 운영자 결정 **증감폭 상대비율**(min_material_pct, scoring.yml) — YouTube 반올림 노이즈 컷([[subscriber-delta-materiality]]).

**동향 리스트는 §4.5 그대로.** 대표 영상/성과 컬럼은 §4.5에 없어 추가하지 않는다(리스트 자체가 "동향"). 아바타 파스텔은 §10 badge/surface 토큰에서 채널명 해시로 결정적 선택(신규 팔레트 발명 금지).

**수동 등록/제외는 쓰기 — index 와 분리.** 등록은 `Youtube::RegisterChannel` 서비스(스텁 경계)로 메타 조회 후 `source:"manual"` 생성. 실 YouTube 호출은 보류(키 대기, mode 기본 stub). 제외는 `excluded` 토글 — 기존 not_excluded 스코프가 수집·표시·채점에서 자동 제외. 자사(is_own:true)는 경쟁 스코프에서 원천 제외.

**감소 증감 표시.** §4.5는 양수(success-600)만 기술 — 감소는 프롬프트 지침대로 `text-ink-muted` + ↓(성과 배수 밴드와 다른 축, amber/red 아님). 진행 바 풀 스케일은 표시 상수 `bar_full_pct`(데이터 아님).

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어가 test DB에 실제 쿼리·러너를 돌려 실증했고, 핵심 발견에서 수렴했다.

**패치(적용)**
1. **[High·정직성] latest 스냅샷 nil → 가짜 −100% 붕괴** — earliest 만 nil/0 방어하고 `latest.subscriber_count.to_i` 는 nil 을 0 으로 강압 → 건강한 채널이 −100% material decline 으로 오표시(§4.7/AD-9 위반). → 양 끝점 중 하나라도 nil 이면 `:collecting`. 회귀 테스트 추가.
2. **[Med·정직성] 감소 증감에 그린 진행 바** — `:material :down` 이 `bg-success-600`(성장색) 바를 렌더 → 구독자 하락이 성장으로 오독. → 증가만 success-600, 감소는 중립 `bg-ink-subtle`.
3. **[Med] UC-id 정규식 무경계 오탐** — `/UC[\w-]{22}/` 가 "MUCH…" 단어 중간 매칭·23자↑ 과길이 ID 를 조용히 절단. → 앞뒤 경계 lookaround `(?<![\w-])(UC[\w-]{22})(?![\w-])`. 회귀 테스트 추가.
4. **[Med·UX] 중복 등록 영문 메시지 노출** — 모델 유니크 검증이 먼저 `RecordInvalid`(영문 기본 메시지) 발생 → 한국어 `RecordNotUnique` 분기가 死코드. → `errors.of_kind?(:youtube_channel_id, :taken)` 로 한국어 안내, RecordNotUnique 는 경합 안전망 유지. 테스트를 메시지 문자열까지 강화.
5. **[Low] toggle_exclusion 미처리 404** — 자사·삭제·오래된 id → `RecordNotFound` 그대로 404. → `rescue` 친절한 리다이렉트.
6. **[Low] @excluded 불필요 daily_stats 프리로드** — 제외 행은 증감 위젯 없음 → 죽은 I/O 제거.
7. **[Low·드리프트] 측정한계 칩 인라인 복제** — `shared/_honesty_status`의 `:measurement_limit` 와 바이트 동일 → 공유 파셜 재사용으로 §4.7 단일 원천 유지.

**실증으로 기각(오탐)**
- **N+1·읽기전용** — `includes(:daily_stats)` + `channel.daily_stats.sort_by(&:date)`(Ruby Enumerable, SQL ORDER 미부착) → 행 루프 **0 쿼리**, index 는 SELECT 2 + preload, 쓰기·API 호출 없음(AD-3 준수).
- **`Arel.sql("subscriber_count DESC NULLS LAST")`** — 번들 SQLite 3.51.0 는 NULLS LAST(3.30+) 지원, 리터럴이라 주입 없음, nil 실제 마지막 정렬 확인.
- **인증·CSRF** — ApplicationController `include Authentication`(`require_authentication`) 상속 + Rails 8 기본 위조 방지 + form_with/button_to 토큰. create/toggle 보호됨.
- **XSS·중복/카테고리 tamper·빈 이름·빈 리스트·bar_width 클램프** — 모두 안전/의도대로 실증.

**Defer(문서화)**
- **F4 "7일 창" vs "최근 7 스냅샷"** — `stats.last(7)` 은 스냅샷 수 기준. 일별 수집(daily_collection_job)이 정상이면 스냅샷≈일수이며, 렌더 UI 는 "7일"을 직접 주장하지 않고 콜드는 정확한 "D+n" 표기. MVP 수용, 라이브 갭 발생 시 재검토.
- **F6 avatar_initial 코드포인트 단위** — ZWJ/이모지 첫 글자만 표시될 수 있으나 `aria-hidden` 순수 장식. 변경 없음.
- **toggle 비원자성** — 단일 운영자 어드민, 이중 제출 경합 수용.

**추가 테스트(회귀 방지)** — 헬퍼 1건(latest nil → collecting), 컨트롤러 2건(중복 한국어 메시지·정규식 경계 오탐). 전 스위트 410 runs 0 failures.

## Verification

**Commands:**
- `bin/rails test test/controllers/competitors_controller_test.rb test/helpers/competitors_helper_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/competitors app/helpers/competitors_helper.rb` -- expected: 결과 없음
- `grep -rniE "text-(blue|green|red|amber|gray|slate)-[0-9]|bg-(blue|green|red|amber|gray|slate)-[0-9]" app/views/competitors` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **구현**: 읽기 전용 CompetitorsController#index(경쟁 채널 동향 §4.5 — 아바타·채널명·구독자·구독자 증감 3상태) + 수동 등록(Youtube::RegisterChannel, 스텁 경계·실 호출 보류) + 제외 토글. 구독자 증감은 ChannelDailyStat 7-스냅샷 창 읽기(AD-3), 정직성 3상태(데이터 수집 중 / 측정한계=증감폭 상대비율 / 진행 바). 측정한계 기준은 운영자 결정(증감폭 상대비율, scoring.yml subscriber_delta.min_material_pct) — [[subscriber-delta-materiality]].
- **리뷰**: 이중 적대 리뷰 7건 패치(latest-nil 정직성·감소 그린 바·정규식 경계·중복 한국어·404·죽은 프리로드·측정한계 파셜 재사용), 3건 defer. N+1·읽기전용·SQLite NULLS LAST·인증/CSRF·XSS 는 실증 기각.
- **테스트**: `bin/rails test` — **410 runs, 1424 assertions, 0 failures, 0 errors, 0 skips**(회귀 +2). grep — 금지 라벨·원시 팔레트 색 부재.
- **주의**: 초기 서브에이전트 커밋이 루트 proposal.html 을 포함해 amend 로 제거(추적 해제, 파일 보존).
