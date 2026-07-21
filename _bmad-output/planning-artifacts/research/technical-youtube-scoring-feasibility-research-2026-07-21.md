---
stepsCompleted: [1, 2, 3, 4, 5, 6]
inputDocuments:
  - docs/research/youtube-scoring-metrics-benchmark.md
  - docs/research/channel-analysis.md
  - Planning/meeting-transcript.md
  - Planning/planning.md
workflowType: 'research'
lastStep: 6
research_type: 'technical'
research_topic: '확정된 YouTube 채점 방법론의 기술 구현 가능성 검증 (YouTube Data API v3 + Ruby on Rails + SQLite)'
research_goals: '이미 확정된 평가 기준(채널 내부 중앙값 기준선·쇼츠롱폼 분리·회원제외·VPD·에버그린 혼합·외부 임베딩 허용)을 YouTube Data API v3 + Rails + SQLite 상시수집 서버 환경에서 물리적으로 구현 가능한지 공식 문서 근거로 검증'
user_name: 'hwan'
date: '2026-07-21'
web_research_enabled: true
source_verification: true
---

# Research Report: technical

**Date:** 2026-07-21
**Author:** hwan
**Research Type:** technical (구현 가능성 검증)

---

## Research Overview

확정된 평가 기준(채널 내부 중앙값 기준선·쇼츠롱폼 분리·회원제외·VPD·에버그린 혼합·외부 임베딩 허용)을 **YouTube Data API v3 + Ruby on Rails + SQLite + 상시 실행 수집 서버** 환경에서 물리적으로 구현 가능한지, 공식 문서(developers.google.com)를 1순위 근거로 검증한다. 새 설계가 아니라 구현 타당성 검증이다.

**방법론.** API 사실은 developers.google.com 현행 문서로 직접 확인하고 URL을 부착했다(기억 아님). Rails/SQLite/임베딩/표시설계는 병렬 조사 에이전트가 공식 문서·gem 저장소·벤더 가격표로 확인했다. 확정 전제와 충돌하는 사실은 숨기지 않고 "이 전제는 이 환경에서 불가능/부분가능"으로 명시한다.

**최우선 발견 요약.**
1. **쿼터 구조가 2026-06-01자로 대변경됐다.** `search.list`가 공유 1만 풀에서 빠져 별도 버킷(하루 100콜, 콜당 1 unit)으로 분리됐다. 과거 "검색 100콜 = 1만 units 소진"이 사라졌다. → **조회수 갱신은 사실상 공짜, 검색만 하루 100콜로 제약**이라는 새 그림.
2. **쇼츠/롱폼을 API 응답만으로는 확실히 구분할 수 없다.** `isShort` 필드가 없다. duration 휴리스틱(API만, 부정확) 또는 `/shorts/{id}` HTTP 프로브(정확하나 비공식·차단위험) 중 선택해야 한다. → 확정 전제 "쇼츠/롱폼 분리"의 유일한 실질 리스크 지점.
3. **구독자 시계열은 API에 없고, 게다가 값이 3자리 유효숫자로 반올림된다.** 목업의 "구독자 +1.8만"은 직접 스냅샷을 쌓아야 하며, 반올림 때문에 소형 채널의 주간 증감은 노이즈에 묻힌다. → §11 "어렵다"의 기술적 실체.

---

## A. YouTube Data API v3 — 쿼터·비용·필드 (최우선 검증)

### A-1. 일일 기본 쿼터와 메서드별 비용 (공식 확정)

| 항목 | 값 | 비고 |
|---|---|---|
| 기본 일일 쿼터 | **10,000 units/day** (공유 버킷) | 대부분 엔드포인트가 여기서 차감 |
| `search.list` | **별도 버킷: 하루 100콜, 콜당 1 unit** | ⚠️ 2026-06-01 변경 (아래) |
| `videos.list` | **1 unit** / 콜 | 공유 풀 |
| `channels.list` | **1 unit** / 콜 | 공유 풀 |
| `playlistItems.list` | **1 unit** / 콜 | 공유 풀 |
| `videos.insert`(업로드) | 별도 버킷: 하루 100콜 | 우리는 미사용 |
| 최소 비용 규칙 | 잘못된 요청 포함 모든 콜은 **최소 1 unit** | — |

> **비용은 콜당이지 part당이 아니다.** `part=snippet,statistics,contentDetails`를 한 번에 요청해도 `videos.list`는 1 unit이다. 이게 쿼터 예산의 핵심 지렛대다.

출처: [Quota Calculator (determine_quota_cost)](https://developers.google.com/youtube/v3/determine_quota_cost), [Getting Started/Overview](https://developers.google.com/youtube/v3/getting-started), [search.list](https://developers.google.com/youtube/v3/docs/search/list)

### A-2. ⚠️ 2026-06-01 쿼터 대변경 — 프로젝트에 결정적

공식 개정이력 원문:

> **June 1, 2026** — "The YouTube Data API is transitioning to a granular quota system covering smaller sets of methods, starting with `videos.insert` and `search.list`." 이들은 이제 자기만의 별도 쿼터 버킷(각 하루 100콜)을 가진다.

출처: [Revision History](https://developers.google.com/youtube/v3/revision_history)

**의미.** 과거에는 `search.list` 1콜 = 100 units라서, 하루 100번만 검색하면 1만 units가 전부 소진됐다(운영자가 겪었을 병목). 이제 `search.list`는 공유 풀을 건드리지 않고 **자기 버킷에서 하루 100콜**만 쓴다. 결과적으로 **1만 units 전부가 `videos.list`/`channels.list`/`playlistItems.list` 같은 1-unit 조회에 온전히 남는다.** 조회수 갱신 파이프라인이 사실상 공짜가 됐다. 대신 **검색(신규 채널·경쟁 영상 발굴)은 하루 100콜이 단단한 상한**이 됐다.

### A-3. 채널 전체 영상 목록을 받는 가장 싼 경로 (확정: uploads 플레이리스트 경유)

사용자 가설이 맞다. `search.list`로 채널 영상을 도는 건 이제 하루 100콜 버킷을 잡아먹어 비효율적이다. 정답 경로는 다음이다.

1. `channels.list?part=contentDetails,statistics&id=<채널 최대 50개>` → **1 unit / 50채널**. 응답의 `contentDetails.relatedPlaylists.uploads`가 그 채널의 "업로드 전체" 플레이리스트 ID다. (동시에 `statistics.subscriberCount`도 획득 → 구독자 스냅샷 겸용.)
2. `playlistItems.list?part=contentDetails&playlistId=<uploads>&maxResults=50` → **1 unit / 영상 50개**. 페이지네이션으로 전체 영상 ID 확보.
3. `videos.list?part=snippet,statistics,contentDetails&id=<영상 최대 50개>` → **1 unit / 영상 50개**. 조회수·좋아요·댓글·길이·제목·썸네일 일괄 획득.

출처: [channels.list](https://developers.google.com/youtube/v3/docs/channels/list), [PlaylistItems](https://developers.google.com/youtube/v3/docs/playlistItems), [videos.list](https://developers.google.com/youtube/v3/docs/videos/list)

> ⚠️ 검증 필요(본개발 시 실측): `channels.list`가 여러 ID를 콤마로 배치(최대 50)하는 것은 확인됐다. `playlistItems`/`videos.list`도 관행상 배치 50이나, 본개발 초기에 실제 응답으로 재확인 권장.

### A-4. 영상 1개에서 필요한 필드 — 비용과 필드명 (확정)

`videos.list?part=snippet,statistics,contentDetails` 한 콜(**1 unit, 영상 50개까지 배치**)로 전부 나온다.

| 요구 데이터 | 필드(JSON 경로) | part |
|---|---|---|
| 조회수 | `statistics.viewCount` | statistics |
| 좋아요 | `statistics.likeCount` | statistics |
| 댓글수 | `statistics.commentCount` | statistics |
| 업로드일 | `snippet.publishedAt` (RFC3339) | snippet |
| 길이 | `contentDetails.duration` (**ISO 8601**, 예: `PT4M13S`) | contentDetails |
| 제목 | `snippet.title` | snippet |
| 썸네일 | `snippet.thumbnails` | snippet |

⚠️ `likeCount`/`commentCount`는 크리에이터가 숨기면 응답에서 **누락될 수 있다**(키가 아예 없을 수 있음 → 코드에서 nil 방어 필수). `contentDetails.duration`은 ISO 8601이라 Ruby에서 `ActiveSupport::Duration.parse` 또는 정규식 파싱 필요.

출처: [videos.list](https://developers.google.com/youtube/v3/docs/videos/list)

### A-5. 쇼츠 vs 롱폼 판별 — ⚠️ API만으로는 확실히 불가능 (확정 전제의 리스크 지점)

**핵심 사실: Data API v3에 쇼츠/롱폼을 구분하는 공식 필드(`isShort` 등)가 없다.** 두 가지 방법뿐이고 각각 결함이 있다.

**방법 1 — duration 휴리스틱 (API만, 부정확).** `contentDetails.duration`으로 길이를 재서 짧으면 쇼츠로 간주. 문제: 쇼츠 최대 길이가 늘어나 짧은 롱폼(예: 2분짜리 일반 영상)과 겹친다. 길이만으로는 오분류가 난다. 비용 0(이미 받는 필드).

**방법 2 — `/shorts/{videoId}` HTTP 프로브 (정확하나 비공식·차단위험).** `https://www.youtube.com/shorts/<id>`에 HEAD 요청 → **200이면 쇼츠, 303(리다이렉트→`/watch`)이면 롱폼.** 정확도는 높지만 **Data API가 아니라 youtube.com에 직접 치는 비공식 해킹**이라, ①공지 없이 막힐 수 있고 ②대량으로 치면 IP 차단(운영자가 §9에서 겪은 바로 그 문제)이 재발한다.

출처: [How to check if YouTube video is a Short (QuadMeUp)](https://blog.quadmeup.com/2023/03/31/how-to-check-if-youtube-video-is-a-short/), [Identify Shorts via JS (Medium)](https://medium.com/@divyanshbyte/how-to-identify-wether-a-youtube-video-is-shorts-or-not-using-javascript-6ee83726a3a6)

> **확정 전제 "쇼츠/롱폼 기준선 분리"에 대한 판정: 부분 가능.** 분리 계산 로직 자체는 문제없다. 문제는 **분류 신호**다. 권장은 "duration 휴리스틱을 1차로 쓰되, 판별한 결과를 `is_short`로 DB에 캐시하고(영상당 1회, 불변), 경계 근처만 `/shorts/` 프로브로 보정 + 프로브는 저속 스로틀"이다. 프로브를 전량·고속으로 돌리면 차단 위험을 스스로 불러들인다. PRD에 이 제약을 반드시 명시해야 한다.

### A-6. 회원 전용(멤버십) 영상 — API에서 어떻게 보이나 (확정 전제 "회원제외"와 정합)

- `search.list`는 **공개 영상 ID만** 반환하고 회원 전용 영상은 목록에 넣지 않는다.
- 회원 전용 영상은 채널 uploads 플레이리스트를 통해 잡히더라도 **공개 통계(viewCount)가 제공되지 않거나 신뢰할 수 없다**(자사 채널 실측에서 이미 "조회수 가려짐" 확인, `channel-analysis.md` §2-①).
- **자사 채널 인증 토큰이 있어도** Data API로 회원 전용 영상의 "공개 조회수"가 열리지 않는다. 자사 자기 데이터는 별도 API인 **YouTube Analytics API**(OAuth)로 봐야 하고, 이는 Data API와 파이프라인·인증이 다르다. `members.list`는 "누가 멤버인가" 목록일 뿐 영상 통계가 아니다.

출처: [Members](https://developers.google.com/youtube/v3/docs/members), [Members: list](https://developers.google.com/youtube/v3/docs/members/list)

> **판정: 확정 전제와 완전 정합.** "회원 전용 영상을 기준선에서 제외"는 우리 선택이 아니라 **API가 데이터를 안 주기 때문에 강제**되는 것이다. 구현상 자연스럽다(조회수 nil/0이면 기준선 표본에서 제외).

### A-7. 쿼터 예산 계산 — 감당 가능한 채널·영상 상한

**모델.** 일일 갱신은 이미 아는 영상 ID들의 현재 통계만 새로고침한다.
- 일일 `videos.list` = ⌈전체영상수 / 50⌉ units
- 신규 업로드 감지 `playlistItems.list` 1페이지/채널/일 = N units (채널당 1)
- 구독자 스냅샷 `channels.list` = ⌈N / 50⌉ units

| 시나리오 | 채널 N | 영상 M/채널 | 전체 영상 | 일일 units | 1만 대비 |
|---|---|---|---|---|---|
| MVP 현실치 | 50 | 200 | 10,000 | ≈ **251** | 2.5% |
| 확장 | 100 | 500 | 50,000 | ≈ **1,102** | 11% |
| 상한 근처 | 300 | 500 | 150,000 | ≈ **3,300** | 33% |
| 이론 한계 | — | — | ~400,000+ | ~8,000 | 80% |

**초기 백필**(전체 영상 1회 열거): ⌈M/50⌉×2×N. 50×200이면 약 400 units 1회성. 무시 가능.

**결론.** 조회수 갱신 관점에서 **기본 쿼터 1만으로 수만~십수만 영상을 하루 1회 갱신하는 데 전혀 문제없다.** MVP(자사+경쟁 수십 채널)는 1만의 3% 미만만 쓴다. **진짜 상한은 `videos.list`가 아니라 `search.list` 하루 100콜**이다 — 신규 채널·경쟁 영상을 키워드로 발굴하는 작업이 여기 묶인다. 발굴은 주 1회 배치로 몰면 100콜로 충분하다(1콜당 결과 50개).

**쿼터 증액.** 초과 시 Google의 [Quota extension request form](https://developers.google.com/youtube/v3/getting-started)으로 신청한다. 다만 승인은 API 규정 준수 감사(compliance audit)를 동반하고 기간·승인률이 공식적으로 보장되지 않는다(난이도 있음). **우리 규모에선 증액이 필요 없다**는 게 더 중요한 결론이다.

---

## C. 레이트리밋·차단 대응 — 정식 API vs 운영자가 겪은 스크래핑 차단

운영자는 §9에서 "서버에서 막히는 문제"를 겪었다. 이는 거의 확실히 **로컬/스크래핑 방식(yt-dlp 등)의 IP 차단**이었다. 정식 Data API는 실패 모드가 근본적으로 다르다.

| 실패 모드 | 발생 원인 | 표준 대응 |
|---|---|---|
| `quotaExceeded` (403) | 일일 units 소진 | 태평양시 자정 리셋 대기. 우리는 3% 사용이라 무관 |
| `rateLimitExceeded` / `userRateLimitExceeded` (403) | 순간 과도 호출 | 지수 백오프 재시도. 배치를 초당 소량으로 페이싱 |
| `keyInvalid`/`forbidden` | 키 오설정·정지 | 키 회전, 규정 준수 |
| 지역/영상 제한 | 일부 영상 비공개·지역차단 | 응답 누락을 nil로 방어 |

**정식 API는 스크래핑처럼 IP를 차단하지 않는다.** 쿼터·레이트 기반으로 우아하게 실패할 뿐이라, 운영자의 과거 실패는 API 채택만으로 대부분 해소된다.

> **단 하나의 예외 = A-5의 `/shorts/` 프로브.** 이건 API가 아니라 youtube.com 직접 요청이라, 대량 실행 시 운영자가 겪은 IP 차단(429)이 재발할 수 있는 **유일한 지점**이다. 스크래핑 불가피 지점은 여기 하나뿐이며, 저속 스로틀 + 영상당 1회 캐시로 위험을 최소화해야 한다. 그 외 확정 기준은 전부 정식 API만으로 충족된다.

---

## D. 구독자 증감 추적 — §11 "어렵다"의 기술적 실체 규명

목업의 "구독자 증가(최근 7일) +1.8만"에 대한 판정이다.

**사실 1 — 과거 구독자 시계열 엔드포인트가 없다.** Data API에 "특정 과거 시점의 구독자 수"를 주는 엔드포인트는 존재하지 않는다. `channels.list?part=statistics`는 **현재 시점 값**만 준다. → 시계열은 **직접 스냅샷을 쌓는 수밖에 없다**(소급 불가).

**사실 2 — 값이 반올림된다.** 2019년 정책 변경 이후 `statistics.subscriberCount`는 **1,000명 초과 채널에서 유효숫자 3자리로 반올림**된다(예: 123,456 → 123,000). 정확값은 채널 소유자만 YouTube Studio에서 본다.

출처: [Channels 리소스](https://developers.google.com/youtube/v3/docs/channels), [Revision History](https://developers.google.com/youtube/v3/revision_history), [Why YouTube Subscriber Counts are Rounded (Rival IQ)](https://help.rivaliq.com/en/articles/9788197-why-youtube-subscriber-counts-are-rounded)

**"어렵다"의 실체 = 두 가지가 겹친다.**
1. **소급 불가** — 오늘부터 스냅샷을 쌓아야 하므로, 추적 시작 전 구간의 증감은 영원히 만들 수 없다. 조회수 스냅샷과 같은 한계다.
2. **반올림 노이즈** — 자사 채널(구독자 약 1.02만)의 주간 증감은 실제로 수십~수백 명 단위인데, API 값은 10,200 → 10,200(반올림 계단)으로 **변화가 안 보이거나 갑자기 100단위로 튄다.** 대형 채널(수십만~백만)일수록 반올림 폭이 커져(1,000·10,000 단위) 주간 증감이 더 뭉개진다. 목업의 "+1.8만"은 대형 채널에서나 유의미하고, 소형 경쟁 채널에는 사실상 측정 불가다.

**비용은 무료.** 구독자 스냅샷은 A-3의 `channels.list`(구독자·uploads 동시 획득) 안에 이미 얹혀 있어 **추가 콜이 0**이다. 파이프라인은 조회수 스냅샷과 동일하다.

> **판정: 부분 가능 + UI 정직성 필요.** 파이프라인 탑재는 공짜지만, 값의 신뢰도가 채널 규모에 따라 크게 다르다. PRD는 "구독자 증감은 추적 시작 이후만, 반올림 계단 때문에 소형 채널은 노이즈"임을 명시하고, 소형 채널에는 증감을 숨기거나 "±측정한계" 라벨을 붙이는 설계가 필요하다.

---

## E. 주제 단위 묶기 — planning.md의 "다음 주 주제 3개" 산출을 위한 필수 단계

확정 채점은 영상 단위인데 최종 산출물은 "주제 3개"라, 영상→주제 묶기가 필요하다.

**사실 — `relatedToVideoId`는 폐기·제거됐다.** search.list의 "관련 영상" 파라미터는 **2023-06-12 폐기, 2023-08-07 완전 제거**됐다. 현행 문서에 흔적도 없다. → **YouTube가 "관련 영상"을 주는 엔드포인트는 더 이상 없다.** 묶기는 전적으로 우리가 메타데이터로 해야 한다.

출처: [Revision History](https://developers.google.com/youtube/v3/revision_history), [search.list](https://developers.google.com/youtube/v3/docs/search/list)

**주 1회 배치로 돌릴 경량 묶기 후보(무거운 것→가벼운 것).**

| 방법 | 원리 | 정확도 | Rails+SQLite 난이도 | 비용 |
|---|---|---|---|---|
| 임베딩 클러스터링 | 제목(+설명) 임베딩 → 코사인 유사도로 그룹핑 | 높음(다국어 교차) | 중 (F축 참조) | 임베딩 API 소액 |
| 키워드/태그 규칙 | 제목·태그 토큰 겹침, 사전 기반 주제 라벨 | 중 | 낮음 | 0 |
| 하이브리드 | 키워드로 1차 버킷 → 임베딩으로 병합 | 높음 | 중 | 소액 |

> **판정: 가능.** 자사 유사영상 판정(F축)과 **같은 임베딩 인프라를 재사용**하면 주제 묶기가 추가 비용 거의 없이 붙는다. 주 1회 배치로 충분하다. 상세 방법·비용은 F축 결과에 통합한다.

## B. 수집 파이프라인·스케줄러 (Rails 8 + SQLite)

운영자는 로컬 실행으로 실패했다(§9 "컴퓨터 꺼지면 수집 끊김"). 상시 실행 서버가 전제다.

### B-1. 하루 1회 배치 — Solid Queue 반복 작업 권장 (Redis 불필요)

**Solid Queue는 반복(cron) 작업을 내장한다.** `config/recurring.yml`에 선언하고 Fugit이 cron 문법과 자연어("every day at 4am") 둘 다 파싱한다. Rails 8의 **기본 Active Job 백엔드**이며 **SQLite를 저장소로 쓸 수 있어 Redis가 필요 없다.**

```yaml
# config/recurring.yml
production:
  daily_collection:
    class: DailyCollectionJob
    schedule: every day at 4am
```

| 방법 | 2026 유지상태 | Redis | 재시작 후 지속 | 추가 인프라 |
|---|---|---|---|---|
| **Solid Queue + recurring.yml** | Rails 8 **기본**, 코어팀 유지 | **불필요** | O (DB에 스케줄·잡 저장) | 없음 |
| sidekiq-cron | 성숙하나 Sidekiq 기반 | 필요 | Redis 지속설정 | Redis |
| whenever + system cron | 유지되나 OS crontab 래퍼 | 불필요 | OS 의존, 관측성 없음 | OS crontab |
| rake + crontab | 항상 동작, 무의존 | 불필요 | OS 의존, 재시도 없음 | OS crontab |

**권장.** Solid Queue + SQLite. 이미 쓰는 SQLite 파일에 스케줄·잡 상태·재시도·이력이 함께 남고 Redis가 없다. 단 **Solid Queue 스케줄러 프로세스가 상시 떠 있어야 한다**(`bin/jobs` 또는 Puma의 `solid_queue` 플러그인으로 인프로세스 실행). 이게 운영자의 "상시 실행 수집" 요구를 정확히 충족한다.

출처: [solid_queue README](https://github.com/rails/solid_queue/blob/main/README.md), [반복작업 PR #155](https://github.com/rails/solid_queue/pull/155), [AppSignal Solid Queue deep dive](https://blog.appsignal.com/2025/06/18/a-deep-dive-into-solid-queue-for-ruby-on-rails.html)

### B-2. SQLite 동시성 — WAL로 배치쓰기 + 웹읽기 문제 해소

**Rails 8은 SQLite에 기본으로 WAL을 켠다**(`journal_mode=WAL`, `synchronous=NORMAL`, `mmap_size=128MB` 등, Stephen Margheim의 Rails 7.1/8 작업 결과).

```yaml
# config/database.yml (production)
  timeout: 5000
  pragmas:
    journal_mode: WAL
    synchronous: NORMAL
    busy_timeout: 5000
    foreign_keys: true
    cache_size: -64000
    mmap_size: 134217728
    journal_size_limit: 67108864
```

- **WAL에서 쓰기 중에도 다중 읽기가 가능하다**(웹 UI는 스냅샷을 논블로킹으로 읽음).
- **동시 쓰기는 불가**(SQLite는 전 DB 단일 라이터). 두 번째 라이터는 `busy_timeout`만큼 대기 후 `SQLITE_BUSY`.
- **하루 1회 쓰기 + 웹읽기 워크로드에는 경합이 사실상 0.** 배치 트랜잭션을 짧게(네트워크/API 호출을 한 트랜잭션에 묶지 말고 배치 삽입) 유지하고, **Solid Queue/Cache는 별도 SQLite 파일로 분리**(Rails 8 멀티DB 기본)하면 큐 쓰기와 앱데이터 쓰기가 격리된다.

출처: [Rails PR #50460](https://github.com/rails/rails/pull/50460), [fractaledmind SQLite on Rails](https://fractaledmind.com/2024/04/15/sqlite-on-rails-the-how-and-why-of-optimal-performance/), [BigBinary Rails 7.1 SQLite defaults](https://www.bigbinary.com/blog/rails-7-1-comes-with-an-optimized-default-sqlite3-adapter-connection-configuration)

### B-3. 스냅샷 테이블 증가 — SQLite 한계 대비 무시 가능

영상당 일별 1행. 50채널×200영상 = 1만 행/일 = **약 365만 행/년 ≈ 1~2GB**. SQLite 실무 한계(기본 페이지 4KB 기준 파일 **~17.5TB**, 실질 ~2e13 행)보다 5~6자릿수 아래라 **행 수는 병목이 아니다.** 병목은 인덱스·쿼리다.

- `(video_id, date)` 유니크/복합 인덱스(델타 계산 주경로, 중복일 방지) + `date` 인덱스(시간창 스캔·롤업).
- **보존/집계 권장** — 최근 90일은 일단위 유지, 이후는 주단위 집계 테이블로 롤업 후 원본 삭제, 주기적 `VACUUM`. 일일 잡에 함께 실행. 이건 용량 때문이 아니라 핫셋을 작게 유지하기 위함이다.

출처: [sqlite.org/limits](https://www.sqlite.org/limits.html), [Joy of Rails: SQLite](https://joyofrails.com/articles/what-you-need-to-know-about-sqlite)

> **판정: 완전 가능.** 상시 수집(Solid Queue)·동시성(WAL)·이력 축적(수백만 행) 모두 Rails 8 + SQLite 표준 관행으로 해결된다. 폐기·유지중단 gem 불필요.

---

## F. 자사 유사영상 판정 + 주제 묶기 — 다국어(일·한) 임베딩

외부 임베딩/LLM 허용됨. 자사 약 500개(일본어) vs 경쟁 다수(한·일 혼재)를 **주 1회** 교차 비교.

### F-1. 임베딩 API 후보 비교 (1M 토큰당 가격)

| 후보 | 차원 | 가격/1M | 일·한 지원 | Rails 연동 |
|---|---|---|---|---|
| OpenAI 3-small | 1536 | **$0.02** | 다국어, 비라틴 약함 | 매우 쉬움 |
| OpenAI 3-large | 3072 | $0.13 | 전반 우수 | 매우 쉬움 |
| Google gemini-embedding-001 | 3072(→1536/768) | $0.15 | **100+ 언어, MTEB 다국어 선두** | 쉬움(REST) |
| Cohere embed-v4.0 | 1536(256~1536) | $0.12 | **비라틴 명시적 강함** | 쉬움 |
| Voyage voyage-3.5 | 1024 | $0.06 (**200M 무료**) | 최상위, 일·한 커버 | 쉬움, 사실상 $0 |
| **BGE-M3 (로컬)** | 1024 | **무료(연산)** | **MIRACL/MKQA 교차언어 SOTA** | 중(런타임 필요) |
| multilingual-e5-large (로컬) | 1024 | 무료(연산) | Cohere v3 상회 | 중 |

### F-2. SQLite 벡터 저장·검색 — 이 규모엔 Ruby 코사인이 정답

- **sqlite-vec**(Alex Garcia, sqlite-vss 후속)는 **2026 현재 유지**(v0.1.10.alpha.4, 2026-05-18)되고 Rails 8에서 `config/database.yml`의 `extensions:`로 로드 가능(sqlite3 gem ≥2.4.0). 하지만…
- **N≈500 규모에선 과설계다.** 임베딩을 packed-float BLOB/JSON 컬럼에 저장하고 주간 잡에서 메모리로 올려 **Ruby 코사인(선택적으로 numo-narray)** 으로 계산하면 서브초에 끝난다. 네이티브 확장 컴파일·배포 리스크가 없다. sqlite-vec는 코퍼스가 수천~수백만으로 커지면 그때 드롭인 업그레이드.

출처: [sqlite-vec GitHub](https://github.com/asg017/sqlite-vec), [sqlite-vec Ruby 문서](https://alexgarcia.xyz/sqlite-vec/ruby.html), [Rails PR #53827 extensions](https://github.com/rails/rails/pull/53827)

### F-3. 로컬 vs API 정확도 — 이 규모엔 로컬로 충분

JA↔KO 교차언어에서 오픈모델(BGE-M3, mE5)이 MIRACL/MKQA 기준 유료 API와 대등하거나 앞선다. 유료 API가 가장 어려운 스플릿에서 몇 점 높지만, 우리 과제는 **짧은 제목 근접중복 탐지 + 사람이 튜닝하는 임계값**이라 1~3점 nDCG 차가 "이 주제 다뤘나?" 판정을 바꾸지 않는다. 유료 선택 이유는 정확도가 아니라 **무운영(모델 호스팅 불필요)** 이다. `OpenAI 3-small`은 값은 싸나 **한·일 혼재 짧은 제목에서 비라틴 스크립트가 약해 회피**한다.

### F-4. 무료 티어 정정 — Gemini 무료는 축소 중, 프로덕션은 유료 전제

⚠️ **중요 정정.** 앞서 "무료 티어라 공짜"라고 단정했으나 부정확하다. Google이 **2026-04-01자로 무료 티어를 대폭 축소**했다. Pro 모델은 무료에서 제거되어 유료 전용이 됐고, Flash는 2025-12부터 무료 할당량이 50~80% 삭감됐다. 정식 체인지로그도 없었다.

- 단 **`gemini-embedding-001`은 공식 가격 페이지에 아직 Free Tier "Free of charge"로 남아 있다.** 임베딩은 이번 축소에서 예외였다.
- 그러나 **Google이 체인지로그 없이 무료 티어를 계속 깎는 중**이라, 오래 운영할 도구를 무료 티어 위에 세우면 안 된다. **프로덕션은 유료($0.15/1M) 전제로 잡고 결제·지출상한을 연결**한다. 비용은 아래처럼 무시할 수준이라 이래도 손해가 없다.
- "공짜 보장"이 정말 중요하면 **Voyage(200M 토큰 무료 한도 = rate limit이 아닌 실제 할당)** 가 Gemini 무료 티어보다 내구성이 높고, **BGE-M3 로컬**은 자기 서버라 진짜 영구 $0(단 파이썬/ONNX 런타임 부담).

출처: [Gemini API 가격(임베딩 Free Tier 명시)](https://ai.google.dev/gemini-api/docs/pricing), [Google Ends Free Gemini Pro API Access(2026-04-01)](https://www.aipricing.guru/news/google-ends-free-gemini-pro-api-access/), [Voyage 가격](https://docs.voyageai.com/docs/pricing)

### F-5. 월 운영 비용 추정 (Gemini 유료 정가 기준)

임베딩은 **영상당 1회만** 생성(제목 불변)하므로, 매달 과금되는 건 **그 달 신규 발견 영상**뿐이다. 유사도 비교 자체는 Ruby 로컬 계산이라 $0.

가정 — 추적 채널 ~50개, 월 신규 ~1,000영상, 영상당 ~150토큰, `gemini-embedding-001` $0.15/1M, 환율 ≈1,400원/달러.

| 항목 | 계산 | 월 USD | 원화 |
|---|---|---|---|
| 신규 영상 임베딩 | 1,000×150 = 0.15M × $0.15 | **~$0.023** | ~₩32 |
| 넉넉한 시나리오 | 2,000×200 = 0.4M × $0.15 | ~$0.06 | ~₩84 |
| (선택) 추천문 생성 LLM | Flash로 주1회 배치 | $0.1~1 | ₩150~1,400 |
| **합계** | — | **$1 미만(대개 수십 센트)** | **₩수백 원** |

- **최초 1회 백필**(자사 500 + 경쟁 과거분 ~1.5만) ≈ **$0.3~0.5(₩450~700) 1회성**.
- 추천 이유 문장을 데이터 템플릿으로 만들면 LLM 비용 $0, Gemini 생성모델로 쓰면 위 (선택) 행이 붙는다 — 그래도 사용자 2명·주1회 내부도구라 월 $1~2를 넘기 어렵다.
- **진짜 월 고정비는 API가 아니라 상시 실행 서버 호스팅(소형 VPS 월 $5~10)** 이고, Gemini 비용은 그 옆에서 반올림 오차다.

> **판정: 완전 가능.** 권장 = ①저장은 BLOB+Ruby 코사인(네이티브 확장 불필요, **DB는 SQLite 그대로**), ②임베딩은 **YouTube와 벤더를 Google로 통일하는 `gemini-embedding-001`을 유료 결제로 사용**(무료 티어 의존 금지). YouTube API와 **서로 다른 키**지만 같은 Google 계정·결제·콘솔로 묶인다. "공짜 확실"을 원하면 Voyage, "외부의존 제거"를 원하면 BGE-M3 로컬. 임계값은 알려진 중복/비중복 제목 쌍으로 실측 튜닝(기본 0.8 신뢰 금지). E축 주제 묶기도 **같은 임베딩 재사용**으로 추가비용 없이 붙는다.

**sqlite-vec 전환 기준(참고)** — 벡터는 스냅샷과 달리 **매일 늘지 않고 영상 늘 때만** 증가한다(제목 불변, 영상당 1개). 벡터 수가 **약 5만 개를 넘거나** 유사도 검색을 웹 요청당 실시간으로 돌려야 할 때 sqlite-vec로 드롭인 업그레이드하면 되고, 그전까지는 Ruby 코사인이 용량·속도 모두 충분하다(768차원 = 영상당 ~3KB, 1만 영상 ~30MB).

출처: [OpenAI 3-small 모델카드](https://developers.openai.com/api/docs/models/text-embedding-3-small), [Gemini API 가격](https://ai.google.dev/gemini-api/docs/pricing), [Cohere embed-v4 가격](https://embeddingcost.com/cohere), [Voyage 가격](https://docs.voyageai.com/docs/pricing), [BGE-M3](https://www.emergentmind.com/topics/bge-m3-embedding-model), [mE5 arXiv](https://arxiv.org/pdf/2402.05672), [MTEB leaderboard](https://huggingface.co/spaces/mteb/leaderboard)

---

## G. 규모 다른 채널의 공정 정렬·비교 (표시 설계)

채널 내부 기준선은 채점을 공정하게 하지만, 여러 채널 영상을 한 테이블에 raw 조회수로 정렬하면 대형 채널이 소형 채널의 진짜 대박을 묻어버린다.

### G-1. 실제 리서치 도구들의 수렴된 답

vidIQ·Viewstats·1of10·OutlierKit 모두 **성과 배수를 히어로 지표로 크게·색상밴드로 표시하고 raw 조회수는 2차로 강등**한다. 동시에 **구독자 규모 밴드 필터**를 1급 컨트롤로 제공한다(정규화만 믿지 않는다). vidIQ는 배수를 색으로 구분(<2x 흑, 2~5x 청, 5~10x 자, >10x 적)하고 구독자 0~10M 밴드 필터를 둔다. OutlierKit은 **20x+ 는 재현 불가능한 외부 요인이 많다**고 경고해 3~10x로 유도한다.

출처: [vidIQ Outliers](https://support.vidiq.com/en/articles/9660010-outliers), [1of10](https://1of10.com/features/homepage-outliers), [OutlierKit Outlier Scores](https://outlierkit.com/resources/outlier-scores/)

### G-2. 일반 데이터시각화 원칙

공통 기준선으로 인덱싱(우리 배수=중앙값 대비 1.0x가 정확히 이것), 정규화 지표를 **기본 정렬키+시각적 주인공**으로, 원시값은 2차, 동종 그룹 내 순위(소형 다중·티어링), 규모차 큰 원시값은 로그축.

출처: [Dallas Fed 인덱싱](https://www.dallasfed.org/research/basics/indexing), [Number Analytics Power of Scale](https://www.numberanalytics.com/blog/power-of-scale-data-visualization), [Storytelling with Data](https://www.storytellingwithdata.com/blog/dont-let-your-axis-scales-distort-the-story)

### G-3. 이 대시보드 권장 (PRD 표시 제약)

1. **기본 정렬 = 성과 배수(조회수÷채널 최근 중앙값) 내림차순. raw 조회수 기본정렬 금지.**
2. 배수가 히어로 셀 — 가장 크게·볼드·색상밴드(<2x 중립/2~5x 청/5~10x 자/>10x 적).
3. raw 조회수는 2차 뮤트 컬럼.
4. **기본 그룹핑 = 구독자 밴드 티어**(<1만 / 1만~10만 / 10만~50만 / 50만+), 밴드 내에서 배수 정렬 → 소형 채널 대박이 자기 슬롯을 얻음. 평면 토글 제공.
5. 구독자 밴드 필터 + 배수 임계 프리셋(2x/3x/5x/10x/25x).
6. **신뢰도 하한** — 최근 롱폼 ≥10개 없으면 기준선 저신뢰 플래그(소형·짧은 창 왜곡 방어, 벤치마크 §G와 정합).
7. **절대조회수 하한 필터**(기본 1~5천) — 40뷰의 50x 같은 플루크 차단.
8. 극단 배수(>25x) "검증 요망 — 외부요인 가능" 플래그.
9. **쇼츠/롱폼은 기준선·필터 차원에서 분리 유지**(중앙값을 절대 공유하지 않음).

> **판정: 순수 표시 설계로 완전 해결됨.** 시장이 이미 우리 설계(채널 내부 배수)로 수렴했다. 정규화만으로 부족하니 **티어링 + 신뢰도/절대값 하한**을 더한다.

---

## 종합 (Synthesis)

### 1. "확정 전제 중 이 환경에서 그대로는 불가능/부분가능한 것" + 대안

| 확정 전제 | 판정 | 근거 | 대안·완화 |
|---|---|---|---|
| 채널 내부 중앙값 기준선 대비 배수 | ✅ 완전 가능 | `videos.list` 1콜로 조회수 획득 | — |
| **쇼츠/롱폼 기준선 분리** | ⚠️ **부분 가능(분류 신호가 문제)** | API에 `isShort` 없음(A-5) | duration 휴리스틱 1차 + `/shorts/` 프로브 보정(저속·영상당1회 캐시). **PRD 필수 명시** |
| 회원 전용 영상 제외 | ✅ 완전 가능(강제됨) | API가 회원영상 통계 안 줌(A-6) | 조회수 nil→표본 제외. 자연스러움 |
| VPD(일일 델타) | ✅ 가능(2일차부터) | 스냅샷 축적 필요 | 오늘부터 스냅샷 시작 |
| 에버그린 (A)+(B) 혼합 | ✅ 가능 | 대리지표 즉시 + 스냅샷 승격 | 벤더 검증지표 부재는 이미 반영됨 |
| 외부 임베딩으로 유사영상 판정 | ✅ 완전 가능 | 비용 ~$0, 로컬도 충분(F) | Cohere/Gemini/Voyage 또는 BGE-M3 |
| Rails + SQLite 상시수집 | ✅ 완전 가능 | Solid Queue + WAL(B) | Redis 불필요 |
| **구독자 증감(목업 "+1.8만")** | ⚠️ **부분 가능(반올림 노이즈)** | 시계열 없음+3자리 반올림(D) | 스냅샷 축적, 소형채널은 "±측정한계" 라벨. **PRD 명시** |
| **주제 단위 묶기**("주제 3개") | ✅ 가능(우리 구현) | `relatedToVideoId` 폐기(E) | 임베딩 클러스터링(F 재사용) |
| **시점 정합 배수**(영상 나이 t일 시점) | ❌ **소급 불가** | 과거 조회수 시계열 API 없음 | MVP는 현재 누적 조회수로, 편향을 UI 명시(벤치마크 §4-3과 동일 결론) |

**그대로는 불가능한 것은 사실상 하나 — 시점 정합 배수의 소급**이고, 이건 이미 벤치마크에서 인지된 구조적 결손이다. 나머지는 완전 가능하거나, 두 지점(쇼츠판별·구독자반올림)에서 "부분 가능 + 완화책 + UI 정직성"으로 해결된다.

### 2. 쿼터 예산 — 감당 가능한 상한 (재확인)

- 기본 **10,000 units/day**로 **수만~십수만 영상 하루 1회 갱신 가능**(MVP 50채널×200영상 = 251 units, 2.5%).
- **진짜 상한은 `search.list` 하루 100콜**(2026-06-01 신설 별도 버킷) — 신규 채널·경쟁 영상 발굴 전용. 주 1회 배치로 몰면 충분.
- 증액 신청은 규정감사 동반·승인 불확실이나, **우리 규모에선 불필요**.

### 3. 외부 의존 비교 (요약)

| 의존 | 용도 | 비용 | 난이도 | 권장 |
|---|---|---|---|---|
| YouTube Data API v3 | 조회수·메타·구독자 | 무료(쿼터내) | 낮음 | 필수 |
| 임베딩 API | 유사영상·주제묶기 | 유료 정가로도 월 수십 센트 | 낮음(REST) | **`gemini-embedding-001` 유료(YouTube와 벤더 통일)**. 무료 티어 의존 금지 |
| Voyage(대안) | 동상 | 200M 토큰 무료 한도 | 낮음 | "공짜 확실" 원하면 |
| BGE-M3 로컬(대안) | 동상 | 무료(연산) | 중(런타임) | 외부의존 제거 원하면 |
| `/shorts/` HTTP 프로브 | 쇼츠 판별 보정 | 무료 | 낮으나 **차단위험** | 저속·캐시 필수 |
| sqlite-vec | 벡터검색 | 무료 | 중 | **불채택(N=500엔 Ruby 코사인)** |

### 4. PRD에 반드시 명시할 기술 제약 목록

1. **쿼터** — Data API 기본 1만 units/day, `videos.list`/`channels.list`/`playlistItems.list` 각 1 unit(콜당, part 무관). 영상 열거는 uploads 플레이리스트 경유(`channels.list`→`playlistItems.list`→`videos.list` 배치 50). `search.list`는 **별도 버킷 하루 100콜** 상한 → 발굴은 주 1회 배치.
2. **쇼츠 판별 불완전** — `isShort` 필드 없음. duration 휴리스틱 + `/shorts/` 프로브(저속·영상당1회 캐시, 대량고속 금지=IP차단). 쇼츠/롱폼 기준선·필터 완전 분리.
3. **회원 전용 영상** — API가 통계 미제공 → 기준선 표본에서 제외(nil 방어). 자사 자기데이터는 별도 YouTube Analytics API 영역.
4. **구독자 증감** — 시계열 API 없음(오늘부터 스냅샷), 값은 3자리 반올림 → 소형채널 주간 증감은 노이즈. 소형채널 UI에 측정한계 표시. 추가 API 비용 0(channels.list에 동승).
5. **시점 정합 소급 불가** — 추적 이전 영상은 "영상 나이 t일 시점 조회수"를 못 만듦. MVP는 현재 누적 조회수 기준 + 오래된 영상 유리 편향을 UI 명시.
6. **스택** — Solid Queue 반복작업(config/recurring.yml) + SQLite, Redis 불필요, 스케줄러 프로세스 상시 실행 필수. SQLite WAL(Rails 8 기본) + busy_timeout 5000ms, 단일 라이터(배치 트랜잭션 짧게), Solid Queue/Cache는 별도 DB 파일.
7. **스냅샷 테이블** — `(video_id, date)` 유니크 인덱스, 90일 일단위 후 주단위 롤업+VACUUM. 행 수는 SQLite 한계 대비 무시 가능.
8. **유사영상/주제묶기** — 임베딩은 `gemini-embedding-001` **유료 결제**로 사용(무료 티어 축소 중이라 의존 금지, YouTube와 같은 Google 계정·다른 키). 월 비용 수십 센트(신규 영상만 과금, 영상당 1회). 저장은 **BLOB+Ruby 코사인(DB는 SQLite 그대로, 네이티브 확장 불필요)**, 벡터 5만 초과 시 sqlite-vec 전환. 임계값 실측 튜닝. `relatedToVideoId` 폐기라 관련영상 API 없음.
9. **표시** — 기본 정렬=성과 배수, 구독자 밴드 티어링, raw 조회수 강등, 신뢰도 하한(최근 롱폼≥10)·절대조회수 하한·극단배수(>25x) 플래그.
10. **레이트리밋** — 정식 API는 IP 차단 없이 쿼터/레이트로 실패(403 지수백오프). 운영자의 과거 스크래핑 차단(§9)은 API 채택으로 해소. 유일 예외 = `/shorts/` 프로브.

---

## 조사의 한계

- API 사실은 developers.google.com 현행 문서로 확인했으나, **본개발 초기에 실제 응답으로 배치 크기·필드 존재를 재확인**해야 한다(특히 likeCount/commentCount 누락, playlistItems/videos.list 배치 50).
- 2026-06-01 쿼터 변경은 아직 새로워 서드파티 문서에 구정보(“검색=100 units”)가 남아 있다. **공식 개정이력을 기준**으로 삼았다.
- 쇼츠 판별 `/shorts/` 프로브는 비공식이라 공지 없이 깨질 수 있다. 대체(duration only)의 오분류율은 대상 채널 실데이터로 측정 필요.
- 임베딩 정확도 비교는 공개 벤치(MIRACL/MTEB) 기반이며, 자사 일·한 제목 도메인 실측은 소규모 라벨셋으로 검증 권장.
