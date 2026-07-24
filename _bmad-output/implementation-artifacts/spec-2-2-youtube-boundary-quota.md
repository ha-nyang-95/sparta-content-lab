---
title: 'Story 2.2: YouTube API 단일 클라이언트 경계 + 쿼터 원장'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
warnings: []
baseline_revision: '1a6b8d65fca97c665c810964eda72cd79c5c06dd'
final_revision: '916ca27fbf519105d247710d1f2f94db98097f29'
---

<intent-contract>

## Intent

**Problem:** YouTube 호출이 여러 곳에 흩어지면 쿼터 회계·백오프·nil 방어가 중복·누락된다(AD-1). 아직 API 키가 없어 실호출은 불가하나, 나머지 파이프라인은 지금 개발돼야 한다.

**Approach:** 모든 YouTube 호출이 단일 통과하는 `app/services/youtube` 경계를 만든다. 경계는 단일 쿼터 원장(공유 1만 units + `search.list` 100콜/일 버킷, 재시도 소비 포함)·배치 50·403 지수 백오프를 소유한다. `YOUTUBE_API_MODE`(stub/live)로 어댑터를 분기 — **Stub 어댑터는 실제 YouTube Data API v3 응답 형태의 녹화 fixture를 반환**(스텁 실행 시 로그로 "아직 진짜 아님" 표식), Live 어댑터는 실 HTTP 골격(키 없으면 명확히 raise). 경계·스텁·쿼터·백오프는 스텁에 대고 완결·테스트하고, **Live 실호출 실데이터 검증만 '보류(키 대기)'**로 남긴다.

## Boundaries & Constraints

**Always:**
- 모든 YouTube 호출은 `app/services/youtube/*`를 단일 통과한다(AD-1). 컨트롤러·모델·뷰·잡에서 `Net::HTTP`/YouTube SDK 직접 호출 없음(grep 테스트로 가드).
- 단일 쿼터 원장 — 공유 **10,000 units/일** 풀(channels.list·playlistItems.list·videos.list 각 **1 unit/콜**) + `search.list` **별도 버킷 100콜/일**(콜당 1). 비용은 콜당(part당 아님). 재시도 소비도 원장에 회계. 초과 시 명확한 예외.
- 배치 50 — channels.list·videos.list는 ID를 50개씩 배치해 콜당 1 unit(이 경계 안에서만 배치 관리). playlistItems는 maxResults=50 페이지네이션.
- 403(quota/rate) 실패는 지수 백오프로 재시도(상한 있음). 재시도 소비는 쿼터 원장에 반영.
- API 키는 Rails credentials 또는 ENV(`YOUTUBE_API_KEY`)로만, **이 경계에서만** 읽는다. 하드코딩 금지(secrets_isolation_test가 가드).
- `YOUTUBE_API_MODE` env 분기(기본 stub). stub → Stub 어댑터(fixture), live → Live 어댑터. Stub 실행 시 `Rails.logger`로 STUB 모드 로그.
- Stub fixture는 **실제 API 응답 형태 그대로** — `items[]`·`statistics.viewCount`/`subscriberCount`·`contentDetails.relatedPlaylists.uploads`·`contentDetails.duration`(ISO 8601 `PT#M#S`)·`snippet.title`/`publishedAt`/`thumbnails`·`nextPageToken`. **likeCount/commentCount가 누락된 아이템을 최소 1개 포함**(nil 방어 하방 검증용). 키 오면 fixture→실응답 교체만으로 동작하게.

**Block If:**
- (없음 — 스텁으로 완결. 실호출은 의도적으로 보류.)

**Never:**
- 실제 YouTube HTTP 호출을 stub 모드/테스트에서 수행(키 없음, 네트워크 금지).
- 응답을 Video/Channel로 파싱·저장(2.3 소관). 이 경계는 전송·쿼터·형태까지.
- 스텁을 "진짜인 척" 만들기 — 보류 상태·STUB 로그가 표식.
- 스코어링·스냅샷·잡 스케줄(2.4·2.5·Epic 3).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 배치 50 | list_videos(120 IDs) | 3콜(50/50/20), 3 units 차감, 120 items 병합 | — |
| 공유 풀 초과 | 누적 10,000 units 후 1콜 | `Youtube::QuotaExceeded` | — |
| search 버킷 | search 101번째 콜 | search 버킷 초과 예외(공유 풀 무관) | — |
| 403 백오프 | 어댑터가 403 2회 후 성공 | 백오프 재시도 후 성공, 재시도분 쿼터 회계 | 상한 초과 시 raise |
| stub 모드 | YOUTUBE_API_MODE=stub | Stub 어댑터·fixture 반환·STUB 로그 | — |
| live 무키 | mode=live, 키 없음 | Live 어댑터가 명확히 raise(ConfigurationError) | — |
| 통계 누락 | videos fixture like/comment 없음 | 그대로 통과(경계는 형태 보존, nil은 2.3이 방어) | — |

</intent-contract>

## Code Map

- `app/services/youtube/client.rb` -- 공개 경계: list_channels/list_playlist_items/list_videos/search. 배치·쿼터·백오프 소유
- `app/services/youtube/quota_ledger.rb` -- 공유 풀 + search 버킷 회계, 초과 예외
- `app/services/youtube/adapters/stub.rb` -- fixture 반환(실 응답 형태), STUB 로그
- `app/services/youtube/adapters/live.rb` -- 실 HTTP 골격(키 필요, 없으면 raise) — 실호출 검증은 보류(키 대기)
- `app/services/youtube/errors.rb` -- QuotaExceeded/RateLimited/ConfigurationError
- `app/services/youtube/config.rb` -- 모드·키 읽기(ENV/credentials, 경계 전용)
- `lib/youtube/stubs/*.json` (또는 유사) -- 녹화 fixture(channels/playlistItems/videos/search)
- `test/services/youtube/*` -- 배치·쿼터·백오프·모드·fixture 형태·grep 가드

## Tasks & Acceptance

**Execution:**
- [x] `app/services/youtube/config.rb` + `errors.rb` -- 모드(`YOUTUBE_API_MODE` 기본 stub)·키(ENV/credentials, 경계 전용) 읽기, 예외 클래스 -- 키 격리 AC
- [x] `app/services/youtube/quota_ledger.rb` -- 공유 10,000 units + search 100콜/일 버킷 회계, `charge`/`remaining`, 초과 시 `QuotaExceeded`, 재시도 소비 포함 -- 쿼터 원장 AC
- [x] `app/services/youtube/adapters/stub.rb` + `lib/youtube/stubs/*.json` -- 실 API 형태 fixture(likeCount/commentCount 누락 아이템 포함) 반환, STUB 로그 -- 스텁 AC
- [x] `app/services/youtube/adapters/live.rb` -- 실 HTTP 골격(Net::HTTP, 키 없으면 raise, 응답 파싱은 stub과 동일 형태) -- 실호출은 보류(키 대기)
- [x] `app/services/youtube/client.rb` -- 경계: list_channels/list_videos(배치 50)·list_playlist_items(페이지)·search(버킷). 쿼터 charge·403 지수 백오프 재시도, 모드로 어댑터 선택 -- 경계·배치·백오프 AC
- [x] `test/services/youtube/*` + grep 가드 -- 배치 50·쿼터 초과·search 버킷·백오프·모드 분기·fixture 형태·경계 밖 Net::HTTP 부재 -- 검증

**Acceptance Criteria:**
- Given YouTube 호출이 필요할 때, when 어떤 호출부든, then 오직 `app/services/youtube/*`를 통과한다(컨트롤러·모델·뷰·잡에 Net::HTTP/SDK 직접 호출 없음, grep 검증).
- Given 이 경계, when 호출을 회계하면, then 공유 1만 units 풀과 `search.list` 100콜/일 버킷을 각각 회계한다(재시도 소비 포함).
- Given 배치 요청, when list_channels/list_videos를 부르면, then 50개씩 배치되어 콜당 1 unit으로 관리된다.
- Given 403(quota/rate) 실패, when 호출하면, then 지수 백오프로 재시도한다.
- Given API 키, when 읽으면, then credentials/ENV에서만·이 경계에서만 읽는다(하드코딩 없음).

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 9: (high 1, medium 3, low 5)
- defer: 1: (low 1)
- reject: 1: (low 1)
- addressed_findings:
  - `[high]` `[patch]` `client.rb`/`stub.rb`/fixture `each_playlist_item`가 stub 모드에서 무한 페이지(정적 스텁이 항상 nextPageToken 반환) → 쿼터 소진까지 폭주(2.3이 즉시 물림). 스텁을 pageToken 인지로 2페이지 종료 + `MAX_PAGES` 안전 상한 + 종료 테스트 추가(실증: yielded 6 종료).
  - `[medium]` `[patch]` `adapters/live.rb` 403을 전부 RateLimited로 뭉갬 → 일일쿼터 소진(quotaExceeded)이 무의미 재시도. reason 파싱해 quotaExceeded/dailyLimitExceeded→QuotaExceeded, 그 외→RateLimited(키 도착 후 실검증).
  - `[medium]` `[patch]` `boundary_test.rb` 가드가 controllers/models/views/jobs/helpers·좁은 정규식만 → app/services 형제·lib·타 HTTP 스택(Faraday/HTTParty/RestClient/open-uri) 누락. 스캔 범위 app+lib(경계 제외)·패턴 확대 + 경계 밖 API 키 접근 가드 추가.
  - `[medium]` `[patch]` `adapters/live.rb` `Net::HTTP.get_response` 타임아웃 없음(행 위험) → `Net::HTTP.start` open/read timeout(5/15s).
  - `[low]` `[patch]` `stub.rb` 누락 fixture가 raw `Errno::ENOENT` → `Youtube::Error`로 래핑(경계 예외 계약).
  - `[low]` `[patch]` `quota_ledger.rb` 음수 units가 @spent 감소 → `ArgumentError`.
  - `[low]` `[patch]` `config.rb` `credentials.dig`가 master key 부재 시 raise → rescue→nil.
  - `[low]` `[patch]` `client.rb` `MAX_RETRIES`를 `BACKOFF_DELAYS.length`로 파생(딜레이-재시도 결합 오설정 방지).
  - `[low]` `[patch]` `config/application.rb` `autoload_lib` ignore에 `youtube` 추가(lib/youtube가 오토로드 루트라 향후 .rb 네임스페이스 충돌 방지).
- deferred: batch 부분 실패 시 완료분 items 폐기·쿼터는 소비됨(all-or-nothing) — 2.3/2.5 잡이 채널/배치별 증분 저장으로 재페치 낭비를 막아야 함.
- rejected(noise): 스텁이 배치마다 동일 fixture 반환(배치 계약은 주입 test double이 검증·정적 스텁 고유 한계).

## Design Notes

**쿼터 사실(기술 조사 §A, 2026-06-01 변경).** 공유 10,000 units/일: `videos.list`/`channels.list`/`playlistItems.list` 각 1 unit/콜(part 수 무관, 배치 50). `search.list`는 공유 풀에서 빠져 **별도 버킷 하루 100콜**. 즉 조회수 갱신은 사실상 공짜, 검색만 100콜 상한. 쿼터 원장은 두 버킷을 분리 회계한다. (이 값들은 API 사실이라 상수 — scoring.yml 튜닝값 아님.)

**수집 체인 형태(2.3이 소비).** channels.list(part=contentDetails,statistics, id≤50) → `contentDetails.relatedPlaylists.uploads` + `statistics.subscriberCount`; playlistItems.list(part=contentDetails, playlistId, maxResults=50, 페이지) → `contentDetails.videoId`; videos.list(part=snippet,statistics,contentDetails, id≤50) → `statistics.viewCount`/`likeCount?`/`commentCount?`·`contentDetails.duration`(ISO8601)·`snippet.title`/`publishedAt`/`thumbnails`. likeCount/commentCount는 누락 가능 → fixture에 누락 케이스 포함.

**스텁/라이브 계약.** 어댑터 인터페이스는 `fetch(endpoint, params) -> Hash`(파싱된 JSON). Stub은 fixture를, Live는 Net::HTTP 실응답을 같은 형태로 반환하므로 Client 로직(배치·쿼터·백오프·2.3 파싱)은 어댑터와 무관하게 동작한다. 키 오면 `YOUTUBE_API_MODE=live` + 키 주입으로 전환, fixture를 실응답이 대체한다. Stub 실행마다 `Rails.logger.info("[Youtube] STUB 모드 — 녹화 fixture 반환 …")`.

**백오프.** 403(quota/rate)에 지수 백오프(예: 1·2·4s, 상한 후 raise). 테스트는 sleep 주입(무대기)으로 검증. 재시도마다 쿼터 charge(재시도 소비 회계, AC).

**보류(키 대기).** Live 어댑터의 실 YouTube 응답 검증은 키가 있어야 하므로 그 부분만 보류. 코드 골격·형태 계약은 완성. deferred-work.md와 sprint-status 주석에 명시.

## Verification

**Commands:**
- `bin/rails test test/services/youtube` -- expected: 전부 통과(배치·쿼터·백오프·모드·fixture)
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "c = Youtube::Client.new; p c.list_videos(%w[a b c]).is_a?(Array) || c.list_videos(%w[a b c]).key?('items')"` -- expected: stub 응답(형태 확인)
- 경계 밖 Net::HTTP grep -- expected: app/services/youtube 밖에 YouTube HTTP 직접 호출 없음
- `grep -rInE "AIza" app lib config` -- expected: 매치 없음(키 하드코딩)

## Auto Run Result

Status: done

**구현 요약** — 모든 YouTube 호출의 단일 경계 `app/services/youtube`를 세웠다. Client(배치50·403 지수 백오프·페이지 상한)·QuotaLedger(공유 10,000 units + search 100콜/일 분리 회계, 재시도 소비 포함)·Config(모드·키 ENV/credentials, 경계 전용)·Errors·Stub 어댑터(실 API 형태 fixture·STUB 로그·pageToken 종료)·Live 어댑터(HTTP 골격·403 reason 분기·타임아웃, **실호출은 보류(키 대기)**). YOUTUBE_API_MODE 분기.

**변경/신규 파일** — `app/services/youtube/{client,quota_ledger,config,errors}.rb`·`adapters/{stub,live}.rb`, `lib/youtube/stubs/*.json`(4), `config/application.rb`(zeitwerk errors·lib/youtube ignore), `test/services/youtube/*`(26 tests).

**리뷰 결과** — Blind + Edge Case 병렬. 쿼터·백오프 정확·fixture §A 일치·경계 클린·보류 정직 확인. patch 9(high 1: 스텁 페이지네이션 무한루프 수정; medium 3: live 403 분기·경계 가드 확대·live 타임아웃; low 5), defer 1(배치 부분실패 증분저장), reject 1. intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 87 runs, 478 assertions, 0 failures(Epic 1·2.1 회귀 없음). 경계 밖 YouTube HTTP/키 참조 0, 쿼터 버킷 독립, 배치 50, each_playlist_item 종료(실증), STUB 로그. `proposal.html`(제 것 아님) 미변경·미커밋.

**보류(키 대기)** — Live 어댑터 실 YouTube 라운드트립 검증. 키 오면 mode=live + 키로 전환, fixture→실응답 대조. deferred-work.md·sprint-status 주석에 명시.
