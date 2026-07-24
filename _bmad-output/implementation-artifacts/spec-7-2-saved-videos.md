---
title: 'Story 7.2: 영상 저장 + 저장한 영상 화면'
type: 'feature'
created: '2026-07-25'
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
baseline_revision: '9e5898c58604a0fa99d189a83c87aaa6ec960764'
final_revision: ''
---

<intent-contract>

## Intent

**Problem:** 운영자가 참고할 영상을 저장(북마크)하고 다시 볼 수단이 없다(FR-26). "저장한 영상" 내비 화면이 placeholder다.

**Approach:** 사용자별 `SavedVideo(user, video)` 모델(유니크, AD-14)과 저장/해제 토글 액션(쓰기, 인증·CSRF)을 추가하고, 6.1 공유 `_video_row` 에 **옵션 게이트(`saved_ids` local)** 로 저장 버튼을 얹는다(evergreen 선례 — 낮은 파급). 인기 콘텐츠(탐색)와 저장한 영상 화면(읽기+해제)이 이를 소비한다. 저장한 영상 화면은 얇은 읽기 전용(AD-3)으로 현재 사용자의 저장 영상을 §4.3로 렌더한다.

## Boundaries & Constraints

**Always:**
- **저장 모델**(AD-14) — `SavedVideo`: `belongs_to :user`, `belongs_to :video`; DB 유니크 인덱스 `(user_id, video_id)` + 모델 uniqueness(scope: user). 마이그레이션은 app(primary) DB. `User has_many :saved_videos, dependent: :destroy`; `Video has_many :saved_videos, dependent: :destroy`(영상 삭제 시 정리).
- **토글(쓰기)** — `SavedVideosController`: `create`(현재 사용자 + video 저장) / `destroy`(해제). 인증(`Current.user`) 뒤·CSRF(button_to 폼 토큰). 중복 저장은 유니크로 무해 흡수(find_or_create 또는 rescue). 액션 후 `redirect_back(fallback_location:)` 로 같은 화면 유지. 미로그인은 기존 require_authentication 로 로그인 유도.
- **_video_row 저장 버튼(옵션 게이트)** — `local_assigns[:saved_ids]`(현재 사용자 저장 video_id `Set`) 가 있을 때만 **후행 셀**에 토글 렌더: 저장 안 됨 → `button_to "저장"`(post, create) / 저장됨 → `button_to "저장됨"`(delete, destroy). §10 토큰(저장됨=primary/강조, 저장=outline). `<a>` 밖 별도 `<td>`(anchor 내부 인터랙티브 금지). 기본 미전달 → 셀 없음(6.3 타 탭·6.5 콘텐츠 갭 무변화). N+1 방지: `saved_ids` 는 컨트롤러가 1회 pluck 한 Set(행별 쿼리 금지).
- **인기 콘텐츠 소비** — `@saved_ids = Current.user 저장 video_id Set` 로드, `_video_row` 에 전달 + thead 에 "저장" 헤더 + 밴드 그룹 헤더 colspan 조정(8→9).
- **저장한 영상 화면**(saved 라우트) — `SavedController#index` 읽기 전용: 현재 사용자 `SavedVideo` → video 물질화 값(성과 배수 등) 프리로드(`includes(video: [:channel, :daily_stats, :video_score])`). §4.3 표(`_video_row`, `saved_ids` = 전체 저장분 → 모든 행 "저장됨"·해제 가능). 최근 저장순 정렬. empty("저장한 영상이 없습니다")·loading·반응형(§5)·다국어(§7).
- 색 **DESIGN §10 토큰만**(AD-15). 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**. 정직성(§4.7)·nil 방어(AD-9). 저장 화면 컨트롤러는 읽기 전용(토글만 쓰기).

**Block If:**
- (없음 — FR-26·AC[SavedVideo(user,video) 토글·사용자별 재열람]·6.1 재사용으로 확정. 저장 버튼은 evergreen 식 옵션 게이트로 파급 최소.)

**Never:**
- 저장 화면 index 에서 쓰기(토글은 별도 액션). 저장 버튼을 `<a href=youtube>` 내부에 중첩. 다른 사용자의 저장 노출(사용자별 격리 — 항상 `Current.user` 스코프). 원시 Tailwind 색. "구독자 대비 조회수". _video_row 기본 동작(saved_ids 미전달 시) 변경. 웹 요청 경로 재계산(저장 화면은 물질화 읽기).
- 검색·필터(7.1 완료). 공개(비로그인) 저장.

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 저장 | 미저장 영상 "저장" | SavedVideo 생성, "저장됨" | 중복 → 무해 |
| 해제 | 저장됨 "저장됨"(delete) | SavedVideo 삭제, "저장" | 없어도 무해 |
| 사용자 격리 | 사용자 A 저장 | B 화면엔 안 보임 | — |
| 저장 화면 | 저장 있음 | §4.3 표(전부 저장됨) | — |
| 저장 화면 empty | 저장 0 | "저장한 영상이 없습니다" | — |
| 인기 저장 상태 | saved_ids | 각 행 저장/저장됨 정확 | — |
| _video_row 기본 | saved_ids 미전달 | 저장 셀 없음(무변화) | — |
| 미로그인 | 토글/화면 | 로그인 유도 | require_auth |
| 읽기 전용(화면) | GET saved | SavedVideo 쓰기 없음 | — |
| N+1 | 목록 | saved_ids Set·프리로드 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 모바일 | 좁은 뷰포트 | 표 가로 스크롤·본문 유지 | — |

</intent-contract>

## Code Map

- `db/migrate/<ts>_create_saved_videos.rb` -- (신규) saved_videos(user_id, video_id, timestamps) + 유니크 인덱스 (user_id, video_id) + FK(user, video). app(primary) DB.
- `app/models/saved_video.rb` -- (신규) belongs_to user·video, uniqueness(scope: user).
- `app/models/user.rb`·`app/models/video.rb` -- (수정) `has_many :saved_videos, dependent: :destroy`.
- `config/routes.rb` -- (수정) `resources :saved_videos, only: [:create, :destroy]` (기존 `get "saved"` 유지).
- `app/controllers/saved_videos_controller.rb` -- (신규) create/destroy 토글, 인증·CSRF·redirect_back·사용자 스코프.
- `app/controllers/saved_controller.rb` -- (수정) `#index` 읽기 전용 — Current.user 저장 영상 프리로드.
- `app/views/shared/_video_row.html.erb` -- (수정) 옵션 `saved_ids` 게이트 저장 토글 후행 셀.
- `app/views/popular/index.html.erb` -- (수정) `@saved_ids` 로드·전달 + "저장" thead + 밴드 colspan 9.
- `app/controllers/popular_controller.rb` -- (수정) `@saved_ids` = Current.user 저장 video_id Set.
- `app/views/saved/index.html.erb` -- (수정) placeholder 교체 — §4.3 표(_video_row saved_ids)·empty.
- `test/models/saved_video_test.rb`·`test/controllers/saved_videos_controller_test.rb`·`test/controllers/saved_controller_test.rb` -- 유니크·격리·토글·화면·empty·인증·읽기전용·라벨/색 금지·N+1

## Tasks & Acceptance

**Execution:**
- [ ] `bin/rails g migration CreateSavedVideos` 편집 -- `create_table :saved_videos` (t.references :user, null: false, foreign_key: true; t.references :video, null: false, foreign_key: true; t.timestamps); `add_index :saved_videos, [:user_id, :video_id], unique: true`. `bin/rails db:migrate`(app) 후 schema 반영 -- 스키마 AC
- [ ] `app/models/saved_video.rb` -- `belongs_to :user`; `belongs_to :video`; `validates :video_id, uniqueness: { scope: :user_id }`. `user.rb`·`video.rb` 에 `has_many :saved_videos, dependent: :destroy` -- 모델 AC
- [ ] `config/routes.rb`·`app/controllers/saved_videos_controller.rb` -- `resources :saved_videos, only: [:create, :destroy]`; `#create`: `Current.user.saved_videos.find_or_create_by!(video_id: params[:video_id])` (중복 무해) → `redirect_back(fallback_location: saved_path, notice:)`; `#destroy`: `Current.user.saved_videos.where(video_id: params[:video_id]).destroy_all` (또는 by id) → redirect_back. 사용자 스코프·인증·CSRF -- 토글 AC
- [ ] `app/views/shared/_video_row.html.erb` -- `saved_ids = local_assigns[:saved_ids]`; `if saved_ids` 후행 `<td>` — `saved_ids.include?(video.id)` 면 `button_to "저장됨", saved_video_path(video_id: video.id), method: :delete`(primary 강조), 아니면 `button_to "저장", saved_videos_path(video_id: video.id), method: :post`(outline §4.8). anchor 밖. 기본(nil) → 셀 없음 -- 공유 행 AC
- [ ] `app/controllers/popular_controller.rb`·`app/views/popular/index.html.erb` -- `@saved_ids = Current.user ? Current.user.saved_videos.pluck(:video_id).to_set : Set.new`(읽기 1회); `_video_row` 렌더에 `saved_ids: @saved_ids`; thead "저장" `<th>` 추가; 밴드 그룹 헤더 `colspan="9"` -- 인기 소비 AC
- [ ] `app/controllers/saved_controller.rb`·`app/views/saved/index.html.erb` -- `#index`(읽기 전용): `@saved = Current.user.saved_videos.includes(video: [:channel, :daily_stats, :video_score]).order(created_at: :desc)`; `@saved_ids = @saved.map(&:video_id).to_set`. 뷰: `@saved.any?` 면 §4.3 표(thead 영상/채널/업로드일/조회수/성과 배수/자사 유사영상/저장, `_video_row video: sv.video, saved_ids: @saved_ids`), 없으면 empty "저장한 영상이 없습니다" -- 저장 화면 AC
- [ ] `test/models/saved_video_test.rb`·`test/controllers/saved_videos_controller_test.rb`·`test/controllers/saved_controller_test.rb` -- 유니크(중복 방지)·사용자별 격리·create 저장/destroy 해제·중복 저장 무해·저장 화면 렌더·empty·GET saved 읽기 전용(SavedVideo.count 불변)·미인증 리다이렉트·"구독자 대비 조회수" 부재·원시 색 부재·N+1(saved_ids Set) -- 검증

**Acceptance Criteria:**
- Given 로그인 사용자가 영상을 볼 때, when 저장 버튼을 누르면, then `SavedVideo(user, video)`가 생성되고 토글로 해제된다.
- Given 저장한 영상, when "저장한 영상" 화면을 열면, then 사용자별 저장 목록이 §4.3로 재열람되고 해제할 수 있다.
- Given 사용자 A 의 저장, when 사용자 B 가 보면, then A 의 저장은 보이지 않는다(사용자별 격리).
- Given 저장이 없음, when 저장 화면을 열면, then "저장한 영상이 없습니다" empty 가 표시된다.
- Given `saved_ids` 를 넘기지 않는 소비처(6.3 타 탭·6.5), when 렌더하면, then 저장 셀이 없고 기존 동작이 바뀌지 않는다.
- Given GET /saved, when 처리하면, then SavedVideo 를 쓰지 않는다(읽기 전용, AD-3). 좁은 화면에서 표가 가로 스크롤되고 본문이 가로로 깨지지 않는다.

## Design Notes

**저장 버튼은 evergreen 식 옵션 게이트.** `_video_row` 는 popular·content_gap 공유라, 저장 셀을 `saved_ids` local 있을 때만 후행 `<td>` 로 추가한다(기본 미전달 → 무변화). anchor(youtube 링크) 내부에 버튼을 넣지 않도록 별도 셀. popular·saved 만 `saved_ids` 전달.

**토글은 create/destroy(REST), index 는 읽기.** 저장 화면 컨트롤러는 AD-3 읽기 전용, 쓰기는 SavedVideosController 로 분리. `find_or_create_by!` + 유니크로 중복 저장 무해, destroy 는 사용자 스코프. redirect_back 으로 같은 화면 유지.

**사용자별 격리·N+1.** 모든 저장 쿼리는 `Current.user.saved_videos` 스코프. 목록 저장 상태는 컨트롤러가 `pluck(:video_id).to_set` 1회 로드해 행에서 O(1) 조회(행별 쿼리 금지). 저장 화면은 video 연관 프리로드.

**저장 화면 목업 부재 → §4.3/§4.7/§10.** 저장 화면 레이아웃은 목업에 없어 인기 콘텐츠 표 패턴 재사용(_video_row). 저장 버튼 위치도 목업 미규정 → 행 후행 셀(가장 낮은 파급).

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어가 **보안 핵심(사용자별 격리)·인증·CSRF·읽기전용·컬럼 수·N+1 을 실증으로 CLEARED**.

**실증으로 기각(정상)**
- **사용자별 격리(보안)** — create/destroy/index/@saved_ids 모두 `Current.user.saved_videos` 스코프. B 가 A 의 video_id 로 destroy 해도 B 스코프에 없어 A 행 불변, B 의 저장 화면에 A 저장 미노출(실증).
- **인증** — ApplicationController `require_authentication` 상속(allow_unauthenticated_access 없음) → Current.user non-nil 보장, unauth 는 액션 전 리다이렉트.
- **CSRF** — button_to 폼 토큰, 상태 변경은 POST/DELETE 만(GET 아님).
- **읽기 전용(AD-3)** — saved#index 는 읽기만. **컬럼 수** — popular thead 9 + colspan 9 = 행 9셀, saved 7 = 7셀, content_gap 6(saved_ids 미전달 → 저장 셀 없음, 무회귀) 전부 일치.
- **마이그레이션/스키마** — user_id/video_id NOT NULL·FK·유니크 (user_id,video_id), dependent:destroy 정리. **N+1 없음** — @saved_ids pluck 1회 + O(1) include?, 저장 화면 프리로드 0 per-row(실측).
- **비스칼라 video_id 파라미터**(배열/해시) — Edge Hunter 실증: RecordInvalid 로 흡수(rescued), 크래시 없음. Blind Hunter 의 TypeError 추정은 실증으로 반증됨.

**패치(적용)**
1. **[Low-Med] create 의 RecordNotUnique 미처리 → 동시/이중클릭 500** — `find_or_create_by!` 는 SELECT↔INSERT 비원자. 동일 (user,video) 동시 create 2건 → 유니크 인덱스가 loser 에 RecordNotUnique(rescue 목록에 없음) → 500. 데이터 손상은 없음(인덱스가 막음). → `rescue ActiveRecord::RecordNotUnique` 추가, **성공으로 흡수**(원하는 상태=저장됨 달성 → notice "저장했습니다"). 순차 중복은 find 경로로 이미 무해(기존 테스트 커버). 경합 자체는 비결정적이라 전용 단위 테스트 대신 rescue 로 방어(정직 문서화).

**Defer(문서화)**
- 모델 uniqueness + DB 유니크 이중 가드 — 방어적 정합(순차는 검증, 경합은 인덱스). 의도적.
- destroy 를 video_id 로 키(비-RESTful) — 토글 대칭성 위해 스펙대로. 무해.

**추가 테스트** — 서브에이전트가 유니크·격리·토글·화면·empty·인증·읽기전용 16건 작성. 전 스위트 496 runs 0 failures.

## Verification

**Commands:**
- `bin/rails db:migrate` -- expected: saved_videos 생성
- `bin/rails test test/models/saved_video_test.rb test/controllers/saved_videos_controller_test.rb test/controllers/saved_controller_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/saved app/views/shared/_video_row.html.erb` -- expected: 결과 없음
- `grep -rniE "(text|bg|border)-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-[0-9]" app/views/saved app/views/shared/_video_row.html.erb` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **구현**: SavedVideo(user,video) 유니크 모델(AD-14) + 마이그레이션(app DB) + 저장 토글 SavedVideosController(create/destroy, Current.user 스코프·인증·CSRF·redirect_back) + 6.1 _video_row 옵션 게이트(saved_ids) 저장 버튼 + 저장한 영상 화면(SavedController#index 읽기 전용, §4.3). 인기 콘텐츠·저장 화면이 소비.
- **리뷰**: 이중 적대 리뷰 — **사용자별 격리·인증·CSRF·읽기전용·컬럼 수·N+1 실증 CLEARED**. 패치 1건(RecordNotUnique 경합 흡수), 2건 defer.
- **테스트**: `bin/rails test` — **496 runs, 1702 assertions, 0 failures, 0 errors, 0 skips**. grep — 금지 라벨·원시 색 부재.
- **Epic 7 완료**: 7-1(검색·필터·정렬)·7-2(저장) done → Epic 1~7 전체 완료.
