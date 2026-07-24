# Epic 2 Context: 데이터 수집 파이프라인 (Collection)

<!-- Generated from planning artifacts. Regenerate with compile-epic-context if planning docs change. -->

## Goal

밤사이 추적 채널의 영상 메타·조회수·구독자가 자동으로 수집·축적되어, 이후 스코어링 엔진과 화면이 읽을 원천 데이터가 DB에 생긴다. Epic 2는 아직 화면이 없고 값이 DB에 존재하는 것으로 완성된다. 운영자는 수집의 성공·실패·재시도 이력을 DB로 확인할 수 있어야 한다. 이 에픽은 `DailyCollectionJob`의 잡 골격과 수집 스테이지(채널·영상 열거 → 일별 스냅샷 저장)를 세우고, 별도 주기인 `WeeklyDiscoveryJob`으로 신규 경쟁 채널을 자동 발굴하는 두 파이프라인을 분리해 놓는다.

## Stories

- Story 2.1: Channel · Video 모델 정의 + channel-analysis §5 시드 채널 로드
- Story 2.2: 모든 YouTube 호출을 통과시키는 단일 클라이언트 경계 + 쿼터 원장
- Story 2.3: uploads 재생목록 경유 영상 메타·조회수 열거 + `is_short` 1회 캐시
- Story 2.4: 영상·채널 일별 스냅샷 축적 + 90일 이후 주단위 롤업·VACUUM
- Story 2.5: DailyCollectionJob 체인 골격 + 실행 이력 관측성 + 백업 절차
- Story 2.6: WeeklyDiscoveryJob — 주1회 신규 채널·경쟁 영상 발굴

## Requirements & Constraints

- 하루 1회 자동 수집이 상시 스케줄러(Solid Queue recurring)로 돌아, 운영자 컴퓨터가 꺼져도 끊기지 않는다(FR-1).
- 채널의 uploads 재생목록을 경유해 정식 API로 영상을 열거한다 — 스크래핑 IP 차단을 피하기 위함(FR-2).
- 영상·채널 조회수/구독자를 일별 스냅샷으로 축적해 모든 시계열 지표의 단일 원천을 만든다(FR-3).
- 주 1회 키워드 기반 발굴로 놓친 경쟁 채널을 자동 추가한다(FR-4·FR-15 자동 부분). 시드 로드는 FR-15의 수동 출발점.
- 구독자 증감 추적을 위한 구독자 스냅샷은 `channels.list` 호출에 동승해 추가 API 비용 0으로 수집한다(FR-22 수집 부분).
- API 키는 Rails credentials 또는 ENV에서만, 서비스 경계에서만 읽는다. 코드·리포 하드코딩 금지.

## Technical Decisions

- **단일 API 경계 + 쿼터 원장 (AD-1, AD-13)** — 모든 YouTube Data API v3 호출은 오직 `app/services/youtube/*`를 통과한다. 컨트롤러·모델·뷰·잡에서 `Net::HTTP`/SDK 직접 호출은 금지(grep 검증). 이 경계 한 곳이 공유 1만 units 풀과 `search.list` 100콜/일 버킷을 각각 회계하며 재시도 소비까지 포함한다. `videos.list` 배치 크기 50은 이 경계 안에서만 관리한다. 403(quota/rate)은 지수 백오프로 재시도한다.
- **두 파이프라인 분리 (AD-11)** — 일1회 `DailyCollectionJob`, 주1회 `WeeklyDiscoveryJob`이 각각 별도 Solid Queue recurring. 잡은 스테이지 체인 조립만 하고 로직은 서비스에 위임한다. 일일 체인의 수집 스테이지 순서는 `channels.list → playlistItems.list → videos.list(배치 50) → 일별 스냅샷 저장`이며, 이 뒤로 Epic 3 이후 스테이지가 append된다.
- **일별 스냅샷 단일 원천 + 유니크 제약 (AD-5)** — `VideoDailyStat(video, date, view_count)`·`ChannelDailyStat(channel, date, subscriber_count)`가 VPD·에버그린·구독자 증감·스파크라인의 유일 원천. `(video_id, date)`·`(channel_id, date)` 유니크로 같은 날 중복 행을 원천 차단한다.
- **날짜 경계는 Asia/Tokyo** — 하루 경계는 앱 고정 타임존 `Asia/Tokyo`(JP 대상·수집 시각 기준). 시각 값 자체는 UTC `datetime`. 경계 흔들림에 의한 중복/누락을 막는다.
- **90일 롤업 + VACUUM (AD-6)** — 최근 90일은 일단위로 유지하고 이후는 주단위로 롤업한 뒤 원본 삭제 + `VACUUM`한다. 이 정리는 일일 잡에 동승한다.
- **is_short 1회 캐시 (AD-8)** — `is_short`는 `Youtube::ClassifyShort`가 영상 최초 저장 시 단 1회 duration 휴리스틱으로 판정해 캐시하고 이후 불변이다. 단일 writer·단일 임계이며, 임계는 `config/scoring.yml`에서 읽는다. 쇼츠/롱폼은 이후 기준선·필터·표시에서 중앙값을 절대 공유하지 않는다.
- **nil 방어 (AD-9)** — 회원 전용 영상은 `view_count` nil로 저장한다. `like_count`/`comment_count` 누락도 nil로 방어해 파이프라인이 중단되지 않는다. 좋아요·댓글은 수집·저장만 하고 채점·표시에는 쓰지 않는다.
- **duration은 초 정수로 저장** — `videos.list`의 ISO 8601 원본은 초 정수로 파싱 저장하고 원본은 폐기한다.
- **멀티 DB (AD-12) + 백업 (AD-17)** — SQLite 3파일 분리(app / queue / cache, WAL). 스냅샷 원천인 `app.sqlite3`는 소급 재구성이 불가하므로 일일 백업이 필수이며, queue/cache DB는 백업에서 제외한다.
- **관측성** — 실행 이력(시작·성공·실패·재시도·쿼터 사용량)을 `job_runs` 테이블에 기록한다. 재시도는 일1회 갱신 상한에 포함하지 않는다. 스케줄·잡 상태는 DB에 저장되어 서버 재시작 후에도 지속된다.
- **네이밍** — AR 모델은 단수 PascalCase(`Channel`, `Video`, `VideoDailyStat`, `ChannelDailyStat`, `JobRun`). YouTube 식별자는 `youtube_*_id` 컬럼으로 내부 PK와 구분한다. 서비스는 `app/services/<domain>/` 하위 동사형 클래스(`Youtube::FetchVideos`, `Youtube::ClassifyShort`). 잡은 `<주기><동작>Job`.

## Cross-Story Dependencies

- 스토리 순서는 파이프라인 의존 순서를 그대로 따른다 — 2.1 모델·시드 → 2.2 API 경계·쿼터 → 2.3 영상 열거·is_short → 2.4 일별 스냅샷·롤업 → 2.5 잡 골격·관측성·백업 → 2.6 주1회 발굴. 각 스토리는 앞 스토리의 산출을 전제한다(2.1은 Epic 1의 1.1, 2.2는 1.5·2.1에 의존).
- `DailyCollectionJob`의 체인은 이 에픽에서 완성되지 않고 Epic 2→3→4→5로 자라난다. Epic 2는 수집 스테이지까지만 append하고, 기준선/성과 배수/에버그린은 Epic 3, 임베딩/OwnVideoMatch/갭/클러스터는 Epic 4, 기회 점수/추천은 Epic 5가 순서대로 이어 붙인다.
- **API 키 의존 스토리(2.2·2.3)** — 실제 YouTube API 키가 도착하기 전에는 서비스 경계를 스텁 + 픽스처로 구현·검증하고, 키가 준비되면 실호출로 교체한다. 경계가 단일 접점이라 스텁 교체가 국소적이다.
- **Channel.category 4분류** — 필터 드롭다운의 데이터 홈이며 시드 로드부터 채워진다. 분류는 **직접경쟁 / 한국어교육일반 / 언어교육참고 / 상단퍼널**. channel-analysis §5 시드가 각 카테고리로 매핑된다 — 카테고리1 직접경쟁(トリリンガルのトミ·JOO·다히 Dahi·サットン·seemile·コリアンテナ·미사닝), 카테고리2 한국어교육일반(TTMIK·Talk To Me In 100% Korean·GO! Billy Korean·Korean Unnie), 카테고리3 언어교육참고(だいじろー·あいうえおフォニックス·Kevin's English Room·Sakura English), 카테고리4 상단퍼널(KaoruTV·会社員A/J·ミョリム·留学生じん·あゆたび). 구독자 수·핸들은 대략값이므로 시드 로드 후 API로 정확값·`uploads_playlist_id`를 재확인해야 한다. `excluded: true` 채널은 이후 수집·표시에서 제외한다.
- **발굴 키워드 시드(2.6)** — 발굴 키워드는 설정 단일 소재지(예: `config/discovery.yml` 또는 seed)에서 읽고 코드에 하드코딩하지 않는다(AD-4 튜닝값과 동일 취급). 발굴된 채널은 `Channel(source: auto)`로 추가만 되고 채점은 일일 잡이 담당한다. 발굴은 일1회 갱신과 분리된 주기·별도 쿼터 버킷으로 동작한다.
