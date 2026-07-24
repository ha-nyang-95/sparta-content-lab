---
title: 'Story 2.3: uploads 경유 영상 열거 + is_short 불변 캐시'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-2-context.md'
warnings: []
baseline_revision: 'f1a7d42ef35dc1318fe65c014fd8e6e6a2c5f800'
final_revision: 'a60f55d8986a21257969423308fb8c389f1abbc8'
---

<intent-contract>

## Intent

**Problem:** 추적 채널의 영상 메타·조회수를 수집해 Video로 물질화하는 로직이 없다. 쇼츠/롱폼 분리를 위해 `is_short`가 필요하나 API엔 그 필드가 없다.

**Approach:** 2.2 YouTube 경계(기본 stub 모드)를 소비해 채널별로 uploads 재생목록을 열거하고 videos.list 응답을 Video로 파싱·upsert한다. duration(ISO8601)→초, 통계 누락은 nil 방어(AD-9). `Youtube::ClassifyShort`가 duration 휴리스틱으로 `is_short`를 **최초 분류 가능 시점에 1회** 판정·캐시하고 이후 불변(단일 writer). 실 HTTP는 2.2 Live 어댑터가 보류(키 대기)이므로, 이 스토리는 스텁 fixture에 대고 완결·테스트한다.

## Boundaries & Constraints

**Always:**
- YouTube 접근은 **오직 2.2 `Youtube::Client`**로(직접 HTTP 금지, boundary_test가 가드). 체인: `list_channels([id])`(uploads·subscriber) → `each_playlist_item(uploads)`(videoId, 이미 종료 보장) → `list_videos(ids)`(배치50).
- videos.list 아이템 파싱 — `youtube_video_id`(item id)·`title`(snippet.title)·`view_count`(statistics.viewCount **없으면 nil**)·`like_count`/`comment_count`(누락 **nil**, AD-9)·`duration`(contentDetails.duration ISO8601 `PT#H#M#S`→**초 정수**, 원본 폐기)·`published_at`(snippet.publishedAt→datetime UTC)·`thumbnail`(snippet.thumbnails url).
- 좋아요·댓글은 **수집·저장만**(채점·표시에 쓰지 않는다).
- `is_short`는 `Youtube::ClassifyShort`가 **단일 writer**로 판정 — `is_short`가 nil(미분류)이고 duration이 있을 때만 1회 설정, 이후 **불변**(재판정·덮어쓰기 금지). 임계는 `Scoring::Config.fetch(:is_short, :max_duration_seconds)`(현재 180). duration ≤ 임계면 short.
- 회원 전용/누락 통계 영상은 `view_count` nil로 저장하고 **파이프라인을 중단하지 않는다**. 조회수 갱신형 upsert(재수집 시 view/like/comment/title 갱신, is_short는 불변).
- 채널의 `uploads_playlist_id`·`subscriber_count`를 channels.list 응답으로 갱신(구독자 스냅샷 겸용).

**Block If:**
- (없음 — 스텁으로 완결. 실호출은 2.2 Live가 보류.)

**Never:**
- 실 YouTube HTTP(2.2 Live 보류). 잡·모델·뷰에서 직접 API 호출.
- 일별 스냅샷 저장(2.4)·기준선·스코어링(Epic 3). 여기선 Video 물질화까지.
- `is_short` 두 번째 writer·두 번째 임계(단일 writer·단일 임계, AD-8).
- handle-only 채널(youtube_channel_id nil)의 채널ID 해결·병합(2.2 deferred) — 이 스토리는 스킵+로그.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| duration 파싱 | `PT4M13S` | 253(초 정수), 원본 미저장 | 파싱 불가/nil → duration nil |
| 통계 누락 | statistics에 like/comment 없음 | like_count/comment_count nil, 저장됨 | 중단 없음 |
| 회원 전용 | statistics에 viewCount 없음 | view_count nil, 저장됨 | 중단 없음 |
| is_short 판정 | duration 58s, 임계 180 | is_short true(최초 1회) | duration nil → is_short 미설정(nil) |
| is_short 불변 | 이미 is_short 설정된 영상 재수집 | is_short 유지(재판정 안 함), view_count는 갱신 | — |
| 재수집 upsert | 같은 youtube_video_id 재열거 | 조회수 등 갱신, 중복 행 없음 | — |
| handle-only 채널 | youtube_channel_id nil | 스킵 + 로그(해결은 2.2 deferred) | 중단 없음 |

</intent-contract>

## Code Map

- `app/services/youtube/classify_short.rb` -- `ClassifyShort.short?(seconds)` — 임계(scoring.yml) 기반 bool, nil→nil
- `app/services/youtube/video_attributes.rb` -- videos.list 아이템 → Video 속성 파싱(nil 방어·duration 초·published_at·thumbnail)
- `app/services/youtube/fetch_channel_videos.rb` -- 채널별 체인 열거 + Video upsert(is_short 최초 1회), 채널 uploads·subscriber 갱신
- `test/services/youtube/{classify_short,video_attributes,fetch_channel_videos}_test.rb` -- 파싱·nil 방어·is_short 판정/불변·upsert

## Tasks & Acceptance

**Execution:**
- [x] `app/services/youtube/classify_short.rb` -- `short?(seconds)`: seconds nil→nil, else seconds ≤ `Scoring::Config.fetch(:is_short, :max_duration_seconds)` -- is_short 판정 AC
- [x] `app/services/youtube/video_attributes.rb` -- videos.list 아이템 파싱: id·title·view_count(nil)·like/comment(nil)·duration(ISO8601→초)·published_at(datetime)·thumbnail. duration 파싱은 ActiveSupport::Duration 또는 정규식 -- 파싱·nil 방어 AC
- [x] `app/services/youtube/fetch_channel_videos.rb` -- `call(channel)`: youtube_channel_id 있으면 list_channels로 uploads·subscriber 갱신 → each_playlist_item → list_videos(배치) → Video find_or_initialize_by(youtube_video_id) upsert(속성 갱신, is_short는 nil일 때만 ClassifyShort로 1회 설정). handle-only는 스킵+로그. 채널별 증분 저장 -- 열거·upsert·불변 AC
- [x] `test/services/youtube/*` -- ClassifyShort(short/long/nil)·파싱(nil 방어·duration 초·member-only)·FetchChannelVideos(스텁 열거로 Video 생성·is_short 판정·재수집 시 is_short 불변·view 갱신·중복 없음·handle-only 스킵) -- 검증

**Acceptance Criteria:**
- Given 추적 채널, when 열거를 실행하면, then channels.list→playlistItems.list→videos.list(배치50) 순으로 수집된다(2.2 경계 통과).
- Given videos.list 응답, when 파싱하면, then likeCount/commentCount 누락은 nil로 방어되어 파이프라인이 중단되지 않고, duration(ISO8601)이 초 정수로 저장된다(원본 폐기).
- Given 수집된 영상, when 저장하면, then 좋아요·댓글은 저장만 되고 채점·표시에 쓰이지 않는다.
- Given 영상 최초 저장, when is_short를 판정하면, then `ClassifyShort`가 duration 휴리스틱(임계 scoring.yml)으로 1회 판정·캐시하고 이후 불변이다(단일 writer).
- Given 회원 전용 영상, when 저장하면, then view_count가 nil로 저장된다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5: (high 0, medium 4, low 1)
- defer: 0
- reject: 1: (low 1)
- addressed_findings:
  - `[medium]` `[patch]` `fetch_channel_videos.rb`+`adapters/stub.rb` 채널-스코프 `find_or_initialize_by` + 전역 유니크 인덱스 → 다른 채널의 같은 video id 시 `RecordInvalid` 크래시. 스텁이 채널마다 같은 id를 줘 **다채널 수집(2.5 모드)이 2번째 채널에서 폭주**(실증). 전역 upsert + channel 재연결 + Stub channels_list가 요청 id를 에코(실 API 계약 정합). 다채널 무크래시 테스트 추가.
  - `[medium]` `[patch]` `fetch_channel_videos.rb`+`video_attributes.rb` 라이브/프리미어 `P0D`→duration 0→is_short=true로 동결(VOD 되면 duration만 갱신·불일치). duration>0일 때만 분류(0/nil/음수는 미룸). 음수 duration→nil.
  - `[medium]` `[patch]` `fetch_channel_videos.rb` 트랜잭션 없음 → 루프 중간 save 실패 시 채널만 갱신·부분 저장. 채널별 `transaction`으로 원자화(롤백 테스트).
  - `[medium]` `[patch]` `fetch_channel_videos.rb` channels.list를 `.first`로 신뢰(다채널 fixture 오배정)·subscriberCount/uploads 없을 때 nil로 덮어 좋은 스냅샷 삭제(hiddenSubscriberCount). id로 매칭·값 있을 때만 갱신·미발견 시 스킵.
  - `[low]` `[patch]` `video_attributes.rb`/`fetch_channel_videos.rb` 썸네일 maxres/standard 폴백·video id `.uniq`(스텁 2페이지 중복 방지).
- rejected(noise): is_short 가드의 duration nil 재확인 중복(P2가 duration>0 검사로 재작성, ClassifyShort와 이중이나 무해).

## Design Notes

**체인은 2.2 경계로만.** `Youtube::Client`(기본 stub)의 `list_channels`/`each_playlist_item`/`list_videos`를 쓴다. 스텁 fixture(lib/youtube/stubs)가 3영상을 주는데 모든 nil 케이스를 커버한다 — 0001(full·PT4M13S 롱폼), 0002(PT58S 쇼츠·like/comment 누락), 0003(PT12M4S 롱폼·viewCount 없음=회원전용). 실 fetch는 2.2 Live 보류.

**is_short 단일 writer·불변.** `video.is_short.nil? && seconds`일 때만 `ClassifyShort.short?(seconds)` 설정. 이미 true/false면 절대 재설정 안 함(AD-8, 두 writer·두 임계 금지). duration이 최초에 nil이면 미분류(nil)로 남고 다음 수집에 duration이 생기면 그때 1회 분류(여전히 "최초 분류").

**upsert.** `Video.find_or_initialize_by(youtube_video_id:)` + channel 연결. view_count/like/comment/title/duration/published_at/thumbnail은 매 수집 갱신(조회수는 변한다), is_short만 불변. 채널별로 저장(부분 실패 시 앞 채널 보존 — 2.2 batch 부분실패 deferred 완화).

**duration 파싱.** `ActiveSupport::Duration.parse("PT4M13S").to_i` → 253. 파싱 실패/nil → nil(원본 문자열은 저장 안 함).

**handle-only 채널.** youtube_channel_id nil인 시드는 channels.list(id=…) 불가 → 스킵+로그. forHandle 해결·중복 병합은 2.2 deferred(키 도착 후 실데이터로).

## Verification

**Commands:**
- `bin/rails test test/services/youtube` -- expected: 전부 통과(2.2 + 2.3)
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `bin/rails runner "ch = Channel.where.not(youtube_channel_id: nil).first; Youtube::FetchChannelVideos.new.call(ch); p ch.videos.pluck(:youtube_video_id, :is_short, :view_count, :like_count, :comment_count, :duration)"` -- expected: 3영상, is_short/nil 방어/duration 초 반영

## Auto Run Result

Status: done

**구현 요약** — 2.2 YouTube 경계(stub)를 소비해 채널별 uploads를 열거하고 videos.list를 Video로 물질화한다. `Youtube::ClassifyShort`(is_short duration 휴리스틱·단일 writer·불변)·`Youtube::VideoAttributes`(파싱·nil 방어·duration 초·썸네일)·`Youtube::FetchChannelVideos`(체인 열거·전역 upsert·채널별 트랜잭션). 통계 누락·회원전용 nil 방어, 좋아요·댓글 저장만. 실 fetch는 2.2 Live 보류(키 대기).

**변경/신규 파일** — `app/services/youtube/{classify_short,video_attributes,fetch_channel_videos}.rb`(신규), `adapters/stub.rb`(channels_list 요청 id 에코 — 2.2 스텁을 실 API 계약에 맞춤), `test/services/youtube/{classify_short,video_attributes,fetch_channel_videos}_test.rb`.

**리뷰 결과** — Blind + Edge Case 병렬. is_short 불변·nil 방어·경계·duration rescue 정확 확인. patch 5(medium 4: 다채널 크래시·P0D 오분류·트랜잭션·nil-clobber; low 1: 썸네일/uniq), reject 1. intent_gap·bad_spec 0.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 109 runs, 529 assertions, 0 failures(Epic 1·2.1·2.2 회귀 없음). 단일 채널 3영상(is_short false/true/false·view nil 회원전용·duration 초), 다채널 무크래시, is_short 불변 실증, P0D 미분류, hidden-sub 보존, 트랜잭션 롤백. 경계 격리 유지. `proposal.html`(제 것 아님) 미변경.

**잔여 리스크** — handle-only 시드 채널은 채널ID 미해결로 스킵(2.2 deferred handle→id 병합 후 수집 가능). 스텁 다채널은 같은 fixture id를 에코해 실데이터(채널 전속 id)와 다르나 크래시는 없음. 실 fetch·실데이터 형태 대조는 2.2 Live 보류(키 대기).
