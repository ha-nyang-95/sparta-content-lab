---
title: 'Story 2.6: WeeklyDiscoveryJob — 주1회 신규 채널·영상 발굴'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
warnings: []
baseline_revision: '012ecfe3539ffba5711821d435a316af64e0119c'
final_revision: '5d73e00eb388f7d5d330d8844d241481fa1014a6'
---

<intent-contract>

## Intent

**Problem:** 놓친 경쟁 채널이 추적 대상에 자동으로 들어오지 않는다. 일일 수집(조회수 갱신)과는 다른 주기·다른 쿼터로 신규 채널을 발굴해야 한다.

**Approach:** `WeeklyDiscoveryJob`(주 1회 recurring, 일일 잡과 분리)이 2.2 경계(stub)의 `search.list`(별도 search 버킷 100콜/일)로 키워드 기반 신규 채널을 발굴한다. 키워드 시드는 설정 단일 소재지(`config/discovery.yml`)에서만 읽고(하드코딩 금지, AD-4 취급), 발굴된 채널을 `Channel(source: auto)`로 idempotent 추가한다(채점은 일일 잡). 실 fetch는 2.2 Live 보류(키 대기)이므로 스텁 fixture로 완결·테스트한다.

## Boundaries & Constraints

**Always:**
- `WeeklyDiscoveryJob < ApplicationJob` — 조립만, 로직은 `Youtube::DiscoverChannels`(발굴)·`Channel` upsert에 위임(AD-11). JobRun(2.5) 재사용(job_name "WeeklyDiscoveryJob", reap_stale 포함).
- YouTube 접근은 2.2 `Youtube::Client`(stub 기본)의 `search`로만 — `search.list`는 **별도 search 버킷 하루 100콜**(공유 풀 무관). 발굴은 이 버킷만 소비.
- 키워드 시드는 `config/discovery.yml` 단일 소재지에서만 읽는다(`Discovery::Config`). 코드 하드코딩 금지. 초기 키워드는 잠정(본개발 실측 확정, AD-4 취급) — 4분류로 그룹핑해 발굴 채널의 category를 키워드 그룹으로 부여(잠정, 운영자 재분류 가능).
- 발굴 채널은 `Channel(source: "auto")`로 **추가만** 한다(채점·수집은 일일 잡). search 결과의 `id.channelId`로 후보를 모으고, 이미 존재하는 채널(youtube_channel_id)은 **중복 추가하지 않는다**(idempotent). name은 `snippet.title` 있으면 그것, 없으면 channel_id 폴백(name presence 충족).
- 발굴은 **일1회 갱신과 분리된 주기·별도 쿼터 버킷**으로 동작(config/recurring.yml 별도 엔트리). quota_used는 search 버킷 사용량으로 기록.

**Block If:**
- (없음 — 스텁으로 완결. 실 발굴은 2.2 Live 보류.)

**Never:**
- 실 YouTube HTTP(2.2 Live 보류). 잡에 검색·파싱 로직 복제.
- 발굴 채널 채점·영상 수집(일일 잡 담당). 발굴은 채널 추가까지.
- 키워드 코드 하드코딩. 공유 쿼터 풀 사용(발굴은 search 버킷만).
- 화면·컨트롤러.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 발굴 | stub search, 키워드들 | id.channelId 후보 수집, Channel(source: auto) 생성 | — |
| 중복 채널 | 이미 존재하는 youtube_channel_id | 추가 안 함(idempotent) | — |
| 키워드 소재지 | Discovery::Config | config/discovery.yml만 참조 | 없는 키 KeyError |
| search 버킷 | 키워드당 1콜 | search 버킷만 소비(공유 풀 무관), 100콜 상한 | 초과 시 QuotaExceeded 로그 |
| name 폴백 | 결과에 snippet.title 없음 | name = channel_id | — |
| 관측 | 잡 실행 | JobRun("WeeklyDiscoveryJob") succeeded·quota_used(search) 기록 | 실패 시 failed |

## Code Map

- `config/discovery.yml` -- 발굴 키워드 시드(4분류 그룹, 잠정)
- `app/services/discovery/config.rb` -- `Discovery::Config` 얇은 로더(keywords_by_category)
- `app/services/youtube/discover_channels.rb` -- search.list로 후보 채널 id·category 수집
- `app/jobs/weekly_discovery_job.rb` -- 조립·발굴·Channel(source:auto) upsert·JobRun 기록
- `config/recurring.yml` -- weekly_discovery 주 1회
- `test/services/discovery/*`·`test/services/youtube/discover_channels_test.rb`·`test/jobs/weekly_discovery_job_test.rb`

## Tasks & Acceptance

**Execution:**
- [x] `config/discovery.yml` + `app/services/discovery/config.rb` -- 4분류 그룹 키워드(잠정) + `Discovery::Config.keywords_by_category`(memoize·frozen, 얇음, Scoring::Config 패턴) -- 키워드 소재지 AC
- [x] `app/services/youtube/discover_channels.rb` -- `Youtube::DiscoverChannels.new(client:).call`: 각 (category, keyword)로 `client.search(keyword)` → items 중 `id.channelId` 있는 것 수집 → `{channel_id => {category:, name:}}`(first-wins, name=snippet.title||channel_id). search 버킷 사용 -- 발굴 AC
- [x] `app/jobs/weekly_discovery_job.rb` -- perform: JobRun.reap_stale!·start!("WeeklyDiscoveryJob") → ledger·client → DiscoverChannels.call → 후보 각각 youtube_channel_id 미존재 시 Channel.create!(source:"auto", category, name, youtube_channel_id)(idempotent) → succeed!(quota_used: ledger.spent(:search), channels_processed: 추가수). 실패 fail!+raise -- 잡·발굴·관측 AC
- [x] `config/recurring.yml` -- production에 weekly_discovery: WeeklyDiscoveryJob, 주 1회(일일과 분리 주기) -- 분리 주기 AC
- [x] `test/services/discovery/config_test.rb`·`test/services/youtube/discover_channels_test.rb`·`test/jobs/weekly_discovery_job_test.rb` -- 키워드 로드·발굴·dedup·source auto·search 버킷·JobRun -- 검증

**Acceptance Criteria:**
- Given 별도 recurring 스케줄, when `WeeklyDiscoveryJob`이 주 1회 실행되면, then `search.list`를 하루 100콜 상한(별도 search 버킷) 안에서 사용해 키워드 기반 신규 채널을 발굴한다.
- Given 발굴 키워드, when 읽으면, then `config/discovery.yml` 단일 소재지에서만 읽고 코드에 하드코딩하지 않는다.
- Given 발굴된 채널, when 추가하면, then `Channel(source: auto)`로 추가만 되고(채점은 일일 잡) 이미 존재하는 채널은 중복 추가되지 않는다.
- Given 발굴, when 실행하면, then 일1회 갱신과 분리된 주기·별도 쿼터 버킷(search)으로 동작한다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 4: (high 0, medium 3, low 1)
- defer: 2: (low 2)
- reject: 3: (low 3)
- addressed_findings:
  - `[medium]` `[patch]` `discover_channels.rb` >100 키워드 시 101번째 search가 QuotaExceeded로 전체 발굴 폐기·매주 실패(부분 진행 없음). `QuotaExceeded` rescue→캡에서 지금까지 후보로 graceful 반환(스펙 I/O 매트릭스 "로그·계속" 정합).
  - `[medium]` `[patch]` `weekly_discovery_job.rb` create 루프에 per-candidate rescue 없어 1 후보 실패(RecordInvalid/RecordNotUnique)가 전체 중단·부분 커밋·poison-pill. 후보별 rescue+channels_failed 기록(2.5 daily 패턴 정합).
  - `[medium]` `[patch]` `discovery/config.rb` discovery.yml category 미검증 → 오타 category가 create!에서 RecordInvalid 폭발. `keywords_by_category`가 로드 시 `Channel::CATEGORIES`로 검증 fail-fast.
  - `[low]` `[patch]` `discover_channels.rb` search에 `type: channel` 미전달 → Live에서 혼합(video/playlist) 결과로 50슬롯 낭비. `type: "channel"` 전달(1 unit 동일).
- deferred: (1) auto-발굴 채널 dedup이 youtube_channel_id만 봐 handle-only 시드 채널과 중복 생성 → Live 시 2.2/2.3 handle→id 해결이 유니크 충돌. 2.2 handle→id 해결 deferred를 auto 채널 reconcile까지 확장(Live-only, 현재 stub은 합성 UC라 미도달). (2) auto 채널 name(=channel_id 폴백)이 이후 갱신 안 됨 — FetchChannelVideos가 channels.list snippet.title로 name 보정 필요(Live-only·blank title 희소).
- rejected(noise): category first-wins 영속(잠정·운영자 재분류 설계), reap_stale! 잡 유형 교차(2.5 상속·6h 임계로 무해), video 후보 미수집(AC 제목 과장이나 Approach는 채널 스코프·일일 잡이 발굴 채널 영상 수집).

## Design Notes

**키워드→category.** `config/discovery.yml`은 4분류별 키워드 그룹이다. 발굴 채널의 category는 그 키워드가 속한 그룹으로 잠정 부여한다(운영자가 나중에 재분류). 키워드 값은 본개발 실측 확정(AD-4 튜닝값 취급) — 스파인은 자리만 고정. `Discovery::Config`는 `Scoring::Config`와 같은 얇은 로더(단일 경로·frozen·없는 키 KeyError).

**dedup·name.** 후보는 `id.channelId`로 모은다(search 결과의 채널). 이미 `youtube_channel_id`가 있는 채널은 추가하지 않는다(handle 부분유니크·youtube_channel_id 유니크와 정합). name은 `snippet.title` 있으면 그것, 스텁처럼 없으면 `channel_id`로 폴백(name presence 충족, 일일 잡이 channels.list로 실제 이름 보정).

**분리 주기·버킷.** WeeklyDiscoveryJob은 config/recurring.yml에 일일 잡과 별도로 주 1회 등록되고, `search.list`(search 버킷, 100콜/일)만 소비한다 — 공유 1만 units 풀은 건드리지 않는다(2026-06-01 쿼터 분리, 기술조사 §A-1). JobRun은 2.5를 재사용해 quota_used(search)·상태를 기록한다.

**스텁.** search_list.json 스텁은 채널·영상 후보 1개씩을 주고 query를 무시하므로, 여러 키워드가 같은 후보를 반환한다 → dedup으로 1채널만 생성(테스트에서 확인). 실 발굴은 2.2 Live 보류.

## Verification

**Commands:**
- `bin/rails runner "p Discovery::Config.keywords_by_category.keys"` -- expected: 4분류
- `bin/rails test test/services/discovery test/services/youtube/discover_channels_test.rb test/jobs/weekly_discovery_job_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "WeeklyDiscoveryJob.perform_now; p Channel.where(source: 'auto').count; p JobRun.where(job_name:'WeeklyDiscoveryJob').last&.status"` -- expected: 발굴 채널·succeeded(stub)
- `grep -A3 weekly_discovery config/recurring.yml` -- expected: WeeklyDiscoveryJob 주 1회

## Auto Run Result

Status: done

**구현 요약** — `WeeklyDiscoveryJob`(주1회 recurring, 일일과 분리)이 2.2 경계(stub)의 `search.list`(search 버킷 100콜/일·type=channel)로 키워드 기반 신규 채널을 발굴한다. 키워드 시드는 `config/discovery.yml` 단일 소재지(`Discovery::Config`, category는 로드 시 검증), 발굴 채널은 `Channel(source: auto)`로 idempotent 추가(youtube_channel_id dedup·후보별 rescue). JobRun(2.5) 관측(quota_used=search). 실 발굴은 2.2 Live 보류(키 대기).

**변경/신규 파일** — `config/discovery.yml`·`app/services/discovery/config.rb`·`app/services/youtube/discover_channels.rb`·`app/jobs/weekly_discovery_job.rb`(신규), `config/recurring.yml`, `test/services/discovery/*`·`test/services/youtube/discover_channels_test.rb`·`test/jobs/weekly_discovery_job_test.rb`.

**리뷰 결과** — Blind + Edge Case 병렬. 조립 순수성·키워드 단일소재·주기/버킷 분리 확인. patch 4(medium 3: 쿼터 graceful·per-candidate rescue·category 검증; low 1: type=channel), defer 2(auto-vs-시드 reconcile·name 보정 — Live-only), reject 3. intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 155 runs, 670 assertions, 0 failures(회귀 없음). 발굴 채널 source auto·category∈CATEGORIES, idempotent, search 버킷만(공유 풀 무관), category fail-fast, 쿼터 소진 graceful, recurring 주1회(일일 분리). `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — auto-발굴 채널의 handle-only 시드 reconcile·name 보정은 2.2 Live·handle→id 해결과 함께(deferred). 키워드 값은 잠정(본개발 확정). 실 발굴은 2.2 Live 보류.
