---
title: 'Story 2.1: Channel · Video 모델 + 시드 채널 로드'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
warnings: []
baseline_revision: '8450f7e826617cb844a42636508a6959f0a177c0'
final_revision: '54e823d298d367df929039367eaaf3aa02fbbd08'
---

<intent-contract>

## Intent

**Problem:** 수집 파이프라인이 읽고 쓸 도메인 모델(Channel·Video)이 없고, 1일차부터 추적할 대상 채널이 없다.

**Approach:** `Channel`·`Video` AR 모델과 마이그레이션(primary DB)을 만들고, channel-analysis §5의 경쟁/참고 채널을 `Channel(source: seed)`로 idempotent 로드한다. 시드 데이터 현실(대부분 @handle/이름만, 채널ID·구독자수 미확정)을 반영해 API로 해결될 필드(youtube_channel_id·uploads_playlist_id·subscriber_count)는 nullable로 두고 `handle`을 자리로 둔다. `excluded` 채널은 이후 수집·표시에서 제외된다.

## Boundaries & Constraints

**Always:**
- `Channel`: `youtube_channel_id`(string, nullable — 미해결 시드 존재, 있으면 유니크)·`handle`(string, nullable, @handle 또는 URL)·`name`·`category`(4분류 중 하나)·`source`(seed/auto/manual)·`excluded`(bool, 기본 false)·`subscriber_count`(int, nullable)·`uploads_playlist_id`(string, nullable).
- `Channel.category`는 4분류로 제한 — `직접경쟁`/`한국어교육일반`/`언어교육참고`/`상단퍼널`(inclusion 검증). `source`는 `seed`/`auto`/`manual` inclusion 검증.
- `Video`: `youtube_video_id`(string, 유니크)·`channel` 참조·`title`·`is_short`(bool)·`view_count`(int, **nil 허용**)·`duration`(int 초, nullable)·`published_at`(datetime)·`thumbnail`(string)·`like_count`/`comment_count`(int, **nil 허용**).
- 네이밍 — 외부 식별자는 `youtube_*_id`로 내부 PK와 구분(AD 네이밍). AR 모델 단수 PascalCase.
- 마이그레이션은 **primary DB**에만(멀티DB — queue/cache 아님).
- 시드는 **idempotent**(재실행 중복 없음). channel-analysis §5의 4 카테고리를 `Channel.category` 4분류로 매핑, 전부 `source: seed`. 있는 정보만 저장(youtube_channel_id는 `/channel/UC…` URL에서만, 구독자수는 명시 근사만, "확인 불가"/"검색 유입"은 nil — 날조 금지).
- `excluded: true` 채널은 이후 수집·표시에서 제외(스코프/헬퍼로 표현).
- nil 방어(AD-9) — Video의 view_count/like_count/comment_count는 nil 허용(회원 전용·누락 방어).

**Block If:**
- (없음 — 순수 모델/시드, 외부 호출 없음.)

**Never:**
- YouTube API 호출(2.2/2.3 소관). 시드는 정적 문서(§5)에서만.
- 일별 스냅샷·기준선·스코어링(2.4·Epic 3). daily_stats 모델은 2.4.
- 시드에 실제 채널ID·구독자수를 추측으로 채우기(미확정은 nil, API가 해결).
- 화면·컨트롤러(Epic 6).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 마이그레이션 | 새 마이그레이션 | primary DB에 channels·videos 테이블 | queue/cache엔 없음 |
| 시드 로드 | `bin/rails db:seed` | §5 채널이 `source: seed`로 로드, 카테고리 매핑 | 재실행 시 중복 없음 |
| 잘못된 category | `Channel.new(category: "xxx")` | invalid(inclusion) | — |
| nil 통계 Video | view_count/like/comment nil | valid(저장됨) | — |
| excluded 채널 | `excluded: true` | 수집/표시 스코프에서 제외 | — |
| 미해결 시드 | youtube_channel_id nil, handle 존재 | 저장됨(2.2가 채널ID 해결) | 여러 nil 허용 |

</intent-contract>

## Code Map

- `db/migrate/*_create_channels.rb`·`*_create_videos.rb` -- 스키마(primary), 유니크·인덱스
- `app/models/channel.rb` -- category/source 검증, `has_many :videos`, `excluded` 스코프
- `app/models/video.rb` -- `belongs_to :channel`, nil 방어, 유니크
- `db/seeds.rb` -- §5 채널 idempotent 로드(기존 운영자 seed 뒤에 append)
- `test/models/channel_test.rb`·`video_test.rb` -- 검증·연관·스코프·nil 방어
- `test/models/seed_channels_test.rb` -- §5 시드 로드·매핑·idempotent

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*_create_channels.rb` + `*_create_videos.rb` -- Channel/Video 스키마(primary DB): youtube_channel_id(유니크·null 허용)·handle·name·category·source·excluded(기본 false)·subscriber_count(null)·uploads_playlist_id(null); videos youtube_video_id(유니크)·channel FK·title·is_short·view_count(null)·duration(int null)·published_at·thumbnail·like_count/comment_count(null). `bin/rails db:migrate` -- 스키마 AC
- [x] `app/models/channel.rb` -- category inclusion(4분류)·source inclusion(3종)·`has_many :videos`·`scope :not_excluded`(또는 `active`)·youtube_channel_id 유니크(nil 허용) -- 모델 규약 AC
- [x] `app/models/video.rb` -- `belongs_to :channel`·youtube_video_id 유니크·view_count/like_count/comment_count nil 허용(검증에서 presence 강제 안 함) -- nil 방어 AC
- [x] `db/seeds.rb` -- channel-analysis §5의 4 카테고리를 4분류로 매핑해 `Channel(source: seed)` idempotent 로드(있는 식별자만, 미확정 nil). 기존 운영자 seed 보존 -- 시드 로드 AC
- [x] `test/models/channel_test.rb`·`video_test.rb`·`seed_channels_test.rb` -- 검증·연관·excluded 스코프·nil 방어·시드 매핑·idempotent -- 검증

**Acceptance Criteria:**
- Given 마이그레이션·seed 실행, when 모델이 생성되면, then `Channel`(youtube_channel_id·category 4분류·source·excluded·subscriber_count·uploads_playlist_id)과 `Video`(youtube_video_id·channel 참조·title·is_short·view_count[nil]·duration[초]·published_at·thumbnail·like/comment[nil])가 존재한다.
- Given channel-analysis §5 시드, when 로드하면, then `Channel(source: seed)`로 4분류 매핑되어 등록되고 재실행해도 중복이 없다.
- Given `excluded: true` 채널, when 수집·표시 스코프를 쓰면, then 제외된다.
- Given 회원 전용/누락 통계, when Video를 저장하면, then view_count/like_count/comment_count가 nil이어도 유효하다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5: (high 0, medium 2, low 3)
- defer: 3: (low 3)
- reject: 1: (low 1)
- addressed_findings:
  - `[medium]` `[patch]` `db/seeds.rb` 시드 주석이 "검색 유입 → 구독자 nil"로 오도(값은 정확 — "검색 유입"은 handle 컬럼 마커, 구독자는 별도 "약 N만" 컬럼). 미래 감사자·유지보수자가 유효 데이터를 nil로 "정정"할 위험 → 두 컬럼 규칙을 분리 명시.
  - `[medium]` `[patch]` `db/migrate/…handle` handle에 유니크 인덱스 없어 같은 채널이 handle로 중복 행 여지. 부분 유니크 인덱스(handle IS NOT NULL) 추가 — Story 2.2 handle→채널ID 해결의 dedup 앵커.
  - `[low]` `[patch]` `channel.rb` `excluded` DB null:false인데 모델 검증 없어 `excluded: nil`이 raw DB 예외 → `validates :excluded, inclusion: [true,false]`(검증 에러로).
  - `[low]` `[patch]` `channel.rb` `allow_nil`이 `""`를 방어 못해 빈 문자열이 유니크 인덱스에서 충돌 → `normalizes :youtube_channel_id/:handle` blank→nil(AD-9 nil 방어 정합, 쿼리에도 적용).
  - `[low]` `[patch]` `video_test.rb` duration nil 방어 미검증 → nil 저장 단언 추가.
- deferred: (1) 2.2 handle→UC-id 해결/병합 로직 — 해결 시 기존 UC-id 행과 유니크 충돌 방지 위해 handle로 dedup·merge 후 id 부여(본질적 2.2 설계). (2) `dependent: :destroy`가 영상 이력 cascade 삭제 — 채널 삭제 흐름 도입 시 AD-17(이력 소급 재구성 불가·백업)과 재조정. (3) `会社員A/J` 단일 Channel 행이 두 실채널 표현 — 2.2 channels.list 해결 시 하나로 수렴하는 발산, 추적.
- rejected(noise): integer `limit: 8`(SQLite 동적 8바이트 저장으로 현재 무의미, AD-12 SQLite 확정 — 비-SQLite 포팅 시에만 유효).

## Design Notes

**시드 데이터 현실 → 스키마 결정.** channel-analysis §5(약 20채널)는 대부분 `@handle`/URL만 있고 실제 `youtube_channel_id`(UC…)는 소수(`/channel/UC…` 링크)만, 구독자수는 근사·"확인 불가", 일부는 "검색 유입"으로 이름만이다. 문서가 "본개발 때 API로 정확값·핸들 재확인"을 명시한다. 따라서 `youtube_channel_id`·`uploads_playlist_id`·`subscriber_count`는 nullable로 두고 `handle`을 자리로 둔다 — Story 2.2/2.3(channels.list)이 handle→채널ID·uploads·정확 구독자수를 해결한다. **미확정 값을 추측으로 채우지 않는다(nil).** 이는 AD를 어기는 게 아니라 실현하는 결정이다.

**카테고리 매핑(§5 → Channel.category).** 카테고리1 직접 경쟁군→`직접경쟁`, 카테고리2 한국어 교육 일반→`한국어교육일반`, 카테고리3 언어 교육 참고군→`언어교육참고`, 카테고리4 일본 내 한국 관련(상단 퍼널)→`상단퍼널`.

**idempotency.** 시드는 안정 식별자로 dedup — youtube_channel_id 있으면 그것, 없으면 handle, 둘 다 없으면 name(§5 이름은 distinct). `find_or_create_by`로 재실행 안전. youtube_channel_id 유니크 인덱스는 nil 다중 허용(SQLite).

**Video 시드 없음.** 영상은 API 수집(2.3) 산출이므로 여기선 모델·스키마만. daily_stats(2.4)·is_short 판정(2.3 ClassifyShort)은 후속.

## Verification

**Commands:**
- `bin/rails db:migrate` && `bin/rails db:prepare` -- expected: channels·videos 테이블(primary), 종료 0
- `bin/rails runner "p ActiveRecord::Base.connection.tables.include?('channels'); p SolidQueue::Job.connection.tables.include?('channels')"` -- expected: `true` / `false`(primary만)
- `bin/rails db:seed` && `bin/rails runner "p Channel.where(source: 'seed').count; p Channel.distinct.pluck(:category).sort"` -- expected: §5 채널 수, 4분류
- `bin/rails db:seed` (재실행) `bin/rails runner "p Channel.count"` -- expected: 동일(idempotent)
- `bin/rails test` -- expected: 전부 통과(회귀 없음)

## Auto Run Result

Status: done

**구현 요약** — `Channel`·`Video` AR 모델 + 마이그레이션(primary DB)을 만들고 channel-analysis §5의 경쟁/참고 채널 20개를 `Channel(source: seed)`로 idempotent 로드. 시드 현실(대부분 handle/이름만, 채널ID·구독자수 미확정)을 nullable + `handle` 자리로 반영, 미확정은 nil(날조 금지, 2.2/2.3 API가 해결). `not_excluded` 스코프, nil 방어(view/like/comment/duration).

**변경 파일(주요)**
- `db/migrate/*_create_channels.rb`·`*_create_videos.rb`·`*_add_unique_index_to_channels_handle.rb` — primary DB 스키마 + handle 부분 유니크
- `app/models/channel.rb` — 4분류·source·excluded 검증, youtube_channel_id·handle 유니크(normalizes blank→nil), has_many :videos, not_excluded 스코프
- `app/models/video.rb` — belongs_to :channel, youtube_video_id 유니크, 통계 nil 허용
- `db/seeds.rb` — §5 20채널 매핑·idempotent(운영자 seed 뒤 append)
- `test/models/{channel,video,seed_channels}_test.rb`

**리뷰 결과** — Blind + Edge Case 병렬. 시드 충실도 PASS(20채널·정확 매핑·날조 0), 모델·primary-only(AD-12)·nil 방어·belongs_to 필수 확인. patch 5(주석 정정·handle 유니크·excluded 검증·normalizes·duration 테스트), defer 3(2.2 handle 병합·dependent:destroy·会社員 이중), reject 1(limit:8). intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 61 runs, 423 assertions, 0 failures(Epic 1 회귀 없음). channels·videos primary DB만, 시드 20(3 UC id·4분류)·idempotent, normalizes ""→nil, nil 통계 저장. (리뷰 프로브 잔재 dev DB 정리 완료.)

**잔여 리스크** — handle-only 시드의 채널ID 해결(2.2)이 유니크 충돌 없이 in-place merge 되도록 2.2 설계 필요(deferred). 会社員A/J 단일행 이중 채널. 구독자수·채널ID·uploads는 2.2/2.3 API가 채운다.
