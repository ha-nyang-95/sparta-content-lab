---
title: 'Story 2.4: 일별 스냅샷 축적 + 90일 롤업'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
warnings: []
baseline_revision: 'b6cdc68094079faa022196e4ef0610581b501344'
final_revision: '84be9f35390bc3b1b3287971b182869dfb5767a6'
---

<intent-contract>

## Intent

**Problem:** 모든 시계열 지표(VPD·에버그린·구독자 증감·스파크라인)의 단일 원천인 일별 스냅샷이 없다. 무한정 쌓이면 DB가 비대해진다.

**Approach:** `VideoDailyStat`·`ChannelDailyStat`를 primary DB에 만들고 `(video_id,date)`·`(channel_id,date)` 유니크로 하루 중복을 막는다(AD-5). 날짜 경계는 `Asia/Tokyo`. 스냅샷 저장 서비스가 현재 조회수·구독자수를 오늘(Tokyo) 스냅샷으로 idempotent 기록한다. 90일 지난 일별 스냅샷은 (소유자·ISO주)당 최신 1개만 남기고 나머지를 삭제하는 주단위 롤업 + VACUUM으로 얇게 유지한다(AD-6). 잡 스케줄은 2.5.

## Boundaries & Constraints

**Always:**
- `VideoDailyStat`(video 참조·`date`(date)·`view_count`(int, nullable))·`ChannelDailyStat`(channel 참조·`date`·`subscriber_count`(int, nullable)). primary DB.
- 유니크 — `(video_id, date)`·`(channel_id, date)`. 같은 날 중복 스냅샷 행이 생기지 않는다(AD-5).
- 날짜 경계는 **Asia/Tokyo** — `config.time_zone = ENV["APP_TIME_ZONE"]||"Asia/Tokyo"`. 스냅샷 date는 `Time.zone.today`(Tokyo 날짜). 시각(datetime)은 UTC 저장(AR 기본).
- 스냅샷은 **idempotent** — 같은 (owner, date) 재실행은 upsert(중복 없음, 최신값 갱신).
- **nil 방어** — view_count/subscriber_count가 nil(회원전용·숨김)이면 스냅샷을 만들지 않는다(데이터 포인트 없음, 시계열 노이즈 방지). 파이프라인 중단 없음.
- **일별 스냅샷이 시계열의 단일 원천**(project-context §5). VPD·에버그린·구독자 증감·스파크라인은 이 테이블만 읽는다(후속 에픽).
- 90일 롤업(AD-6) — `date < today-90`인 행을 `(owner, ISO주)`별 최신 date 1개만 남기고 나머지 삭제(누적값 대표=주말값). 원본(그 주의 나머지 일별)은 삭제. + 주기 VACUUM.

**Block If:**
- (없음 — 순수 DB/로직.)

**Never:**
- YouTube API 호출(이미 저장된 Video/Channel로 스냅샷). 잡 스케줄·백업(2.5).
- 기준선·성과 배수·스코어링(Epic 3). 여기선 스냅샷 저장·롤업까지.
- 별도 주간 집계 테이블(같은 테이블을 주단위로 얇게 유지 — date는 실제 날짜 그대로).
- 화면·컨트롤러.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 스냅샷 저장 | Video view_count=1234 | VideoDailyStat(today Tokyo, 1234) 생성 | — |
| nil 통계 | view_count nil(회원전용) | 스냅샷 안 만듦(스킵) | 중단 없음 |
| 같은 날 재실행 | 이미 오늘 스냅샷 존재 | 값 갱신, 중복 행 없음(유니크) | — |
| Tokyo 경계 | UTC 15:00(=Tokyo 익일 00:00) | date=Tokyo 날짜(익일) | — |
| 90일 롤업 | 100일치 일별 스냅샷 | >90일분은 주당 1개(최신)만 남고 삭제, ≤90일분 유지 | — |
| 구독자 스냅샷 | Channel subscriber_count | ChannelDailyStat(today, subs) | nil이면 스킵 |

## Code Map

- `db/migrate/*_create_video_daily_stats.rb`·`*_create_channel_daily_stats.rb` -- 스키마(primary)·유니크
- `app/models/video_daily_stat.rb`·`channel_daily_stat.rb` -- belongs_to·유효성
- `app/models/{video,channel}.rb` -- `has_many :daily_stats`
- `config/application.rb` -- `config.time_zone = Asia/Tokyo`
- `app/services/snapshot/record_daily_stats.rb` -- 오늘 스냅샷 idempotent 기록(nil 스킵)
- `app/services/snapshot/rollup_old_stats.rb` -- 90일 롤업(주단위 씨닝) + VACUUM
- `test/models/*daily_stat_test.rb`·`test/services/snapshot/*` -- 유니크·저장·nil 스킵·Tokyo 경계·롤업

## Tasks & Acceptance

**Execution:**
- [x] `db/migrate/*` + `app/models/{video_daily_stat,channel_daily_stat}.rb` -- 스키마(primary): video/channel 참조·date·view/subscriber_count(nullable)·유니크 (owner_id,date). belongs_to + Video/Channel에 has_many :daily_stats. `bin/rails db:migrate` -- 스키마·유니크 AC
- [x] `config/application.rb` -- `config.time_zone = ENV.fetch("APP_TIME_ZONE","Asia/Tokyo")` -- Tokyo 경계 AC
- [x] `app/services/snapshot/record_daily_stats.rb` -- `call(date: Time.zone.today)`: Video(view_count 있으면) → VideoDailyStat upsert(owner,date); Channel(subscriber_count 있으면) → ChannelDailyStat upsert. nil은 스킵. idempotent -- 스냅샷 저장·nil 방어 AC
- [x] `app/services/snapshot/rollup_old_stats.rb` -- `call(cutoff_days: 90, today: Time.zone.today)`: 각 stat 테이블에서 date<cutoff 행을 (owner, ISO주 %G-%V)별 최신 date 1개만 남기고 delete. `vacuum!`(연결 VACUUM, 트랜잭션 밖) 제공 -- 90일 롤업 AC
- [x] `test/models/*` + `test/services/snapshot/*` -- 유니크(중복 raise)·저장·nil 스킵·idempotent·Tokyo 경계(travel_to)·롤업(100일→주단위 씨닝, ≤90 유지) -- 검증

**Acceptance Criteria:**
- Given 수집이 완료된 날, when 스냅샷을 저장하면, then `VideoDailyStat(video,date,view_count)`·`ChannelDailyStat(channel,date,subscriber_count)`가 기록된다.
- Given 스냅샷, when 같은 날 재실행하면, then `(video_id,date)`·`(channel_id,date)` 유니크라 중복 행이 생기지 않는다.
- Given 스냅샷 date, when 경계를 계산하면, then `Asia/Tokyo`로 고정된다.
- Given 90일 지난 일별 스냅샷, when 롤업하면, then 주단위로 롤업(주당 최신 1개)되고 나머지 원본이 삭제되며 VACUUM된다.
- Given 회원 전용/숨김 통계, when 스냅샷을 저장하면, then nil은 스냅샷을 만들지 않는다(중단 없음).

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5: (high 0, medium 2, low 3)
- defer: 1: (low 1)
- reject: 3: (low 3)
- addressed_findings:
  - `[medium]` `[patch]` `record_daily_stats.rb` recorder가 `not_excluded` 스코프 미사용 → excluded 채널도 스냅샷(수집 제외 위반). excluded 채널의 stale 값이 매일 시계열 오염. 비-excluded로 스코프(video는 channel join, channel은 not_excluded) + 테스트.
  - `[medium]` `[patch]` `record_daily_stats.rb` `find_or_initialize+update!`가 원자 upsert 아님(TOCTOU·동시실행 RecordNotUnique로 체인 중단·부분저장). `upsert_all(unique_by:)`로 원자화(스펙 "upsert" 계약 정합, 타임스탬프 자동).
  - `[low]` `[patch]` `rollup_old_stats.rb` delete `IN` 리스트가 SQLite 변수 상한(32766) 초과 시 크래시(대규모 첫 롤업) → `each_slice(900)` 배치 삭제.
  - `[low]` `[patch]` `rollup_old_stats.rb` `vacuum!`가 트랜잭션 내 호출 시 SQLite 에러 → `transaction_open?` 가드로 명확 실패.
  - `[low]` `[patch]` `test/services/snapshot/*` 다-소유자 롤업 격리(그룹 키 owner_id)·excluded 스킵 테스트 추가.
- deferred: `has_many :daily_stats, dependent: :destroy`(+ channel→videos→daily_stats cascade)가 AD-17 이력 소급 재구성 불가 데이터를 삭제 — 채널 삭제 흐름 도입 시 `restrict_with_exception` 등으로 재조정(2.1 dependent:destroy defer 확장).
- rejected(noise): cutoff 경계주 과다표현(일시·시간 지나면 자기교정), APP_TIME_ZONE DST 오버라이드(의도적 config 노브·기본 Asia/Tokyo), date 파라미터 UTC 오전달(호출자 오류·기본은 Tokyo).

## Design Notes

**롤업 = 주단위 씨닝(별도 테이블 없음).** 누적 조회수의 주단위 대표는 그 주의 마지막 스냅샷 값이다. 그래서 `date<today-90`인 행을 `(owner, ISO주 %G-%V)`로 그룹핑해 최신 date 행만 남기고 나머지를 삭제한다. date는 실제 날짜 그대로 유지되고 값도 실측 그대로다 — 해상도만 일→주로 낮춘다. 삭제는 id로 `delete_all`(배치). MVP 규모(소량)라 메모리 그룹핑 무방, 대규모는 SQL 씨닝으로 대체(주석).

**타임존.** `config.time_zone = Asia/Tokyo`로 `Time.zone.today`가 Tokyo 날짜다. AR `default_timezone`은 UTC 유지(datetime UTC 저장, project-context §5). date 컬럼은 tz 없는 date이므로 Tokyo 날짜를 그대로 저장한다.

**nil 스킵.** 회원전용 영상(view_count nil)·구독자 숨김 채널은 그 날 공개 데이터가 없으므로 스냅샷 행을 만들지 않는다. 시계열에 nil 포인트를 남기지 않아 스파크라인·VPD가 깨끗하다. 기준선 표본 제외(Epic 3)와 별개로, 저장 단계에서 애초에 안 남긴다.

**VACUUM.** `vacuum!`은 `ActiveRecord::Base.connection.execute("VACUUM")` — 트랜잭션 안에서 못 돌리므로 Rails 트랜잭셔널 테스트에서 실행 검증은 생략(잡 2.5가 실제 주기 실행). 씨닝 로직만 단위 검증.

## Verification

**Commands:**
- `bin/rails db:migrate && bin/rails db:prepare` -- expected: video_daily_stats·channel_daily_stats(primary), 종료 0
- `bin/rails runner "p Time.zone.name"` -- expected: `Asia/Tokyo`
- `bin/rails test test/models test/services/snapshot` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "p ActiveRecord::Base.connection.tables.include?('video_daily_stats'); p SolidQueue::Job.connection.tables.include?('video_daily_stats')"` -- expected: true/false(primary만)

## Auto Run Result

Status: done

**구현 요약** — `VideoDailyStat`·`ChannelDailyStat`(primary DB, (owner,date) 유니크)와 `Snapshot::RecordDailyStats`(오늘 Tokyo 스냅샷 원자 upsert·excluded 제외·nil 스킵)·`Snapshot::RollupOldStats`(90일 이후 (owner,ISO주)당 최신 1개 씨닝·배치 삭제·vacuum!). `config.time_zone = Asia/Tokyo`(datetime은 UTC 유지). 일별 스냅샷이 모든 시계열의 단일 원천.

**변경/신규 파일** — `config/application.rb`(time_zone), `db/migrate/*daily_stats*`·`app/models/{video_daily_stat,channel_daily_stat}.rb`(신규)·`app/models/{video,channel}.rb`(has_many), `app/services/snapshot/{record_daily_stats,rollup_old_stats}.rb`, `test/models/*daily_stat*`·`test/services/snapshot/*`.

**리뷰 결과** — Blind + Edge Case 병렬. ISO %G-%V 그룹핑·Tokyo 경계·유니크·nil 스킵 정확 확인. patch 5(medium 2: excluded 스코프·원자 upsert; low 3), defer 1(dependent:destroy AD-17), reject 3. intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 134 runs, 585 assertions, 0 failures(회귀 없음). Time.zone Asia/Tokyo, 테이블 primary만, Tokyo 경계(travel_to UTC15:00→익일), upsert idempotent(50→99·1행), excluded 스킵, 롤업 실증(101일→오래된 10일 주단위 2개 씨닝·최근 91행 유지). `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — dependent:destroy 이력 cascade(2.5 백업·채널 삭제 흐름 시 재조정, deferred). 롤업 메모리 그룹핑은 MVP 규모 가정(대규모는 SQL 씨닝). VACUUM 주기 실행은 2.5 잡.
