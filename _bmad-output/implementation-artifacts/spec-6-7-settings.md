---
title: 'Story 6.7: 설정 화면 — 수집 상태 + API 연결 + 계정'
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
baseline_revision: 'a3678f578e09a2a9dde5c4f6de88bd15b534d6f4'
final_revision: '8caeabb36c3d289361a1898fd95f13a4aff96fe0'
---

<intent-contract>

## Intent

**Problem:** 설정 화면이 placeholder다. 운영자가 수집 잡이 정상 도는지(성공/실패/쿼터), 데이터가 얼마나 신선한지, API 연결이 어떤 상태인지, 로그아웃을 할 수단이 없다.

**Approach:** `SettingsController`가 **읽기 전용 index**(AD-3)로 물질화된 `JobRun`(2.5 수집 잡 관측)을 읽어 최근 수집 이력·데이터 신선도를 §4.3 표로, **API 연결 상태**(YOUTUBE_API_MODE·EMBEDDING_MODE·키 유무 — 값 노출 금지·마스킹)를 정직성 배지로, 데이터 범위·백업 정책(AD-17)을 안내 박스로, 계정(로그인 이메일·로그아웃)을 렌더한다. 키는 .env 로만 관리 — 화면은 상태 표시만(입력 폼 없음, 보안).

## Boundaries & Constraints

**Always:**
- **읽기 전용**(AD-3) — `JobRun` 최근 실행 조회·정렬·집계만. 잡 실행/재계산 없음. API 상태는 `Youtube::Config`/`Embedding::Config` 의 mode·key **유무**만 읽는다(경계 존중, AD-1).
- **수집 상태 섹션** — 데이터 신선도 = 마지막 성공 `DailyCollectionJob`(status succeeded)의 `finished_at`(없으면 "아직 수집 없음" §4.7). 최근 JobRun 표(§4.3): job_name·상태 배지(running/succeeded/failed)·시작/종료·처리/실패 채널·재시도·쿼터·error(있으면 truncate+title). 실패는 §4.7 danger 정직성(숨기지 않음).
- **API 연결 상태 섹션** — YouTube·Gemini 각각: 모드 배지(`stub`=중립 "스텁(개발)" / `live`=success), 키 유무("키 있음"/"키 없음", **값 절대 노출 금지**). live 전환 전제 안내 문구(키 + 빌링). 스텁을 진짜인 척하지 않음(배지로 명시).
- **데이터 범위·백업 섹션**(§4.2 "데이터 범위" 박스, `surface-sunken`) — 추적 채널 수(전체/경쟁/자사, `Channel` 카운트)·스냅샷 보관 안내. 백업 정책(AD-17: primary DB 매일 VACUUM INTO, `storage/backups`)과 최신 백업 파일 시각(있으면). 정보성.
- **계정 섹션** — 로그인 이메일(`Current.user&.email_address`) 표시 + 로그아웃(`button_to "로그아웃", session_path, method: :delete` — 기존 sessions#destroy).
- 색 **DESIGN §10 토큰만**(AD-15). 라벨 "성과 배수(채널 평소 대비)", **"구독자 대비 조회수" 금지**. 상태 문구 §4.7 정합. 반응형(§5, 표 `overflow-x-auto`·본문 가로 스크롤 금지)·다국어(§7)·nil 방어(AD-9). empty(잡 이력 0)/error 상태.

**Block If:**
- (없음 — epic-6-context §45가 설정 콘텐츠[수집 이력·데이터 범위·백업·계정] 규정. 설정 화면 목업은 없으나 §45 + §4.3/§4.7/§10 로 확정. API 키 입력 폼은 보안상 범위 밖[.env 관리].)

**Never:**
- API 키 **값** 노출(유무·마스킹만). 키 입력/수정 폼(웹에서 .env/credentials 쓰기 — 보안 위험, 범위 밖). 웹 요청 경로에서 잡 실행·재계산·수집. 원시 Tailwind 색. "구독자 대비 조회수". 실패 잡 숨김(정직성). live 모드를 임의로 켬(모드는 .env·운영자 소관).
- 스코어링 튜닝값(config/scoring.yml) 편집 UI. 제외 채널 관리(6.4 소관 — 필요 시 링크만). 검색·저장(Epic 7).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 신선도 | 성공 수집 있음 | 마지막 finished_at 표시 | 없으면 "아직 수집 없음" |
| 잡 이력 | JobRun 존재 | 최근 N개 §4.3 표 | 0개 → empty |
| 상태 배지 | running/succeeded/failed | 중립/success/danger | — |
| 실패 잡 | status failed, error | danger 행 + error(truncate) | 숨기지 않음 |
| API 모드 | stub | "스텁(개발)" 중립 배지 | — |
| API 모드 | live | success 배지 | — |
| 키 유무 | 키 있음/없음 | "키 있음"/"키 없음" (값 X) | — |
| 채널 수 | Channel 카운트 | 전체/경쟁/자사 | 0 방어 |
| 백업 | storage/backups | 최신 파일 시각 | 없으면 정책 안내만 |
| 계정 | Current.user | 이메일 + 로그아웃 | user nil 방어 |
| 로그아웃 | DELETE session | sessions#destroy → 로그인 | — |
| 읽기 전용 | GET | JobRun 쓰기 없음 | — |
| 라벨 금지 | 전 화면 | "구독자 대비 조회수" 부재 | — |
| 모바일 | 좁은 뷰포트 | 섹션 스택·표 가로 스크롤 | — |

</intent-contract>

## Code Map

- `app/controllers/settings_controller.rb` -- `#index` 얇게 — 최근 JobRun·마지막 성공·채널 카운트·API 상태·백업 최신·current user 로드(읽기 전용).
- `app/helpers/settings_helper.rb` -- (신규) `job_status_badge(status)`(running/succeeded/failed → {label, klass} §10)·`api_mode_badge(mode)`·`api_key_presence(present)`·`format_job_time(t)`.
- `app/views/settings/index.html.erb` -- placeholder 교체: 수집 상태(신선도+JobRun 표) → API 연결 상태 → 데이터 범위·백업 → 계정. §10 토큰·§4.3·§4.7·§5·§7.
- `app/views/settings/_job_run_row.html.erb` -- (신규) §4.3 잡 행(이름·상태 배지·시각·처리/실패·재시도·쿼터·error).
- `test/controllers/settings_controller_test.rb`·`test/helpers/settings_helper_test.rb` -- 200·읽기 전용·잡 이력/신선도·상태 배지·API 모드/키 유무·키 값 미노출·로그아웃 링크·라벨/색 금지

## Tasks & Acceptance

**Execution:**
- [ ] `app/helpers/settings_helper.rb` -- `job_status_badge(status)`: running→{"실행 중", caution}, succeeded→{"성공", success}, failed→{"실패", danger} (§10 badge/success 토큰); `api_mode_badge(mode)`: :stub→{"스텁(개발)", neutral}, :live→{"실사용", success}; `api_key_presence(present)`: present→"키 있음"/else "키 없음"; `format_job_time(t)`: nil→"—" else `strftime` -- 헬퍼 AC
- [ ] `app/controllers/settings_controller.rb` -- `#index`(읽기 전용): `@job_runs = JobRun.order(created_at: :desc).limit(20)`; `@last_success = JobRun.where(job_name: "DailyCollectionJob", status: "succeeded").order(finished_at: :desc).first`; `@channel_counts = { total: Channel.count, competitor: Channel.competitor.count, own: Channel.own.count }`; `@youtube = { mode: Youtube::Config.mode, key: Youtube::Config.key_present? }`; `@embedding = { mode: Embedding::Config.mode, key: Embedding::Config.key_present? }`(AD-1 경계 술어 — 컨트롤러가 api_key 값을 읽지 않음; Config 에 key_present? 추가); `@backup_latest = Dir.glob(Rails.root.join("storage/backups/*.sqlite3")).max` (파일시스템 읽기·nil 방어); `@current_user = Current.user`. **계산·쓰기 없음** -- 컨트롤러 AC
- [ ] `app/views/settings/_job_run_row.html.erb` -- local `job_run`: job_name·`job_status_badge`·`format_job_time`(시작/종료)·처리/실패 채널(tabular)·재시도·쿼터(nil→"—")·error(있으면 truncate·title, 없으면 "—"). §10 토큰 -- 잡 행 AC
- [ ] `app/views/settings/index.html.erb` -- placeholder 교체 4섹션: (1) 수집 상태 — 신선도 문구 + `@job_runs.any?` 면 §4.3 표(`overflow-x-auto`, thead 잡/상태/시작/종료/처리·실패/재시도/쿼터/오류) `_job_run_row` 컬렉션, 없으면 empty. (2) API 연결 상태 — YouTube·Gemini 각 카드(모드 배지·키 유무·live 전제 안내). (3) 데이터 범위·백업 — `surface-sunken` 박스(채널 카운트·백업 정책 AD-17·최신 백업 시각). (4) 계정 — 이메일 + 로그아웃 button_to(delete session_path). DESIGN §10·§7·§5 -- 화면 AC
- [ ] `test/controllers/settings_controller_test.rb`·`test/helpers/settings_helper_test.rb` -- 200·GET 읽기 전용(JobRun.count 불변)·잡 이력 렌더·성공/실패 상태 배지·마지막 성공 신선도·잡 0개 empty·API 모드 배지(stub)·키 유무 표기·**키 값 미노출**(ENV 키 문자열이 body 에 없음)·로그아웃 링크(delete session)·"구독자 대비 조회수" 부재·원시 색 부재 -- 검증

**Acceptance Criteria:**
- Given 물질화된 JobRun, when 설정 화면을 열면, then 최근 수집 이력(상태·처리/실패·재시도·쿼터·오류)과 마지막 성공 수집 시각(신선도)이 §4.3 표로 렌더된다.
- Given 수집 잡 실패 기록, when 렌더하면, then 실패가 danger 정직성으로 숨김 없이 표시되고 오류 메시지가 truncate 로 보인다.
- Given API 설정, when 화면을 열면, then YouTube·Gemini 의 모드(스텁/실사용)와 키 유무가 표시되고 **키 값 자체는 노출되지 않는다**.
- Given 로그인 사용자, when 계정 섹션에서 로그아웃하면, then 세션이 종료되고 로그인 화면으로 간다.
- Given GET /settings, when 요청하면, then JobRun 을 쓰지 않는다(읽기 전용, AD-3).
- Given 좁은 화면, when 보면, then 섹션이 스택되고 표가 가로 스크롤되며 본문이 가로로 깨지지 않는다.

## Design Notes

**수집 관측은 물질화 JobRun 읽기.** 2.5 수집 잡이 JobRun 에 status·쿼터·채널 처리/실패·error 를 이미 물질화 — 설정은 조회·정렬만(AD-3). 신선도는 마지막 성공 DailyCollectionJob finished_at.

**API 상태는 정직하게, 값은 숨긴다.** Config 경계의 mode·키 유무만 노출(AD-1). 스텁은 "스텁(개발)" 배지로 명시(진짜인 척 금지). 키 값·빌링 상세는 화면에 하드코딩하지 않는다(전환 가능·보안). 키 입력 폼은 .env 관리·보안상 범위 밖.

**설정 화면 목업 부재 → epic-6-context §45 권위.** 수집 이력·데이터 범위·백업·계정 4섹션. §4.3 표·§4.7 정직성·§4.2 "데이터 범위" 박스·§10 토큰으로 구성. 신규 디자인 발명 없음.

## Review Triage Log

이중 적대 리뷰(Blind Hunter + Edge Case Hunter). 두 리뷰어가 **보안 핵심(API 키 값 유출) CLEARED** 확인 — `key_present?` 불리언만 렌더, 컨트롤러/뷰/헬퍼에 `Config.api_key` 호출 없음(grep 확인, api_key 는 live 어댑터 경계 안에서만). 읽기전용·AD-1 경계·XSS 이스케이프·로그아웃·nil 방어 전부 정상.

**구현 편차(서브에이전트, 정당)**
- **`key_present?` 경계 술어 추가** — 스펙의 `Config.api_key.present?` 직접 호출은 AD-1 경계 테스트(app/lib 소스에서 `Config.api_key` 외부 참조 금지)를 위반. `Youtube::Config`/`Embedding::Config` 에 `key_present?`(값 반환 없음) 추가해 키 읽기를 경계 안에 유지 — 스펙 의도("경계 존중, 값 노출 금지")와 완전 정합. 스펙 Task 문구도 갱신.

**패치(적용)**
1. **[Low·보안 defense-in-depth] JobRun.error sink 비밀값 노출 가능성** — live 어댑터가 URL 에 `key=<API_KEY>` 를 싣는다. 오늘은 채널별 rescue 로 키 포함 예외가 run-level error 에 도달 불가하나, 설정 화면이 임의 예외 텍스트의 sink 가 됨. → `redact_secrets` 헬퍼(`key=`/`token=`/`password=` 값 [REDACTED])를 error 렌더에 적용. 보안 회귀 테스트 추가(키 섞인 오류 → 마스킹).
2. **[Low] `File.mtime` ENOENT-only 가드 → EACCES 등에서 500** + **[Low] `Dir.glob.max` 사전순이라 비-app 파일·시계 오차 시 오선택** — 컨트롤러에서 `app-*.sqlite3` 만 대상으로 mtime 최신을 `filter_map{File.mtime rescue nil}.max` 로 선택(모든 파일시스템 예외를 파일 단위로 격리). 뷰에서 File.mtime 제거.
3. **[Low·§5] 긴 이메일 오버플로(본문 가로 스크롤)** — 인라인 `style="word-break:keep-all"` → `min-w-0 truncate` + title(§7 패턴). 인라인 스타일 잔존 0.
4. **[Low·honesty] 신선도 staleness 단서 없음** — "마지막 성공 수집" 에 `(N일 전)` 상대 시각 추가(임계 없이 정직). "최근 20건" 라벨로 절단 명시.

**Defer(문서화)**
- succeeded 인데 finished_at nil(방어적, `succeed!` 로 도달 불가) → "마지막 성공 수집: —". time_ago 는 finished_at 있을 때만 표시하도록 가드함.
- error truncate 는 CSS 만(DOM 엔 전문 전송) — 툴팁 의도. 다KB 오류 시 HTML 팽창은 미세.
- api_mode_badge 미지 모드 → 스텁 폴백(Config.mode 는 :stub/:live 만 반환이라 안전).

**추가 테스트(회귀 방지)** — 헬퍼 redact_secrets 1건, 컨트롤러 키-마스킹 sink 방어 1건. 전 스위트 459 runs 0 failures.

## Verification

**Commands:**
- `bin/rails test test/controllers/settings_controller_test.rb test/helpers/settings_helper_test.rb` -- expected: 전부 통과
- `bin/rails test` -- expected: 전부 통과(회귀 없음)
- `grep -rn "구독자 대비 조회수" app/views/settings app/helpers/settings_helper.rb` -- expected: 결과 없음
- `grep -rniE "(text|bg|border)-(blue|green|red|amber|gray|slate|zinc|emerald|indigo)-[0-9]" app/views/settings app/helpers/settings_helper.rb` -- expected: 원시 색 없음

## Auto Run Result

Status: done

- **구현**: 읽기 전용 SettingsController(AD-3) — 최근 JobRun 수집 이력·데이터 신선도(§4.3 표) + API 연결 상태(모드 배지·키 유무, **키 값 미노출**) + 데이터 범위·백업(AD-17) + 계정(로그아웃). AD-1 경계 존중 위해 `Config.key_present?` 술어 추가.
- **리뷰**: 이중 적대 리뷰 — **API 키 유출 보안 CLEARED**·읽기전용·XSS·nil 방어 실증 정상. 패치 4건(error sink 비밀값 마스킹·백업 mtime 선택 견고화·이메일 오버플로·신선도 상대시각/절단 라벨), 3건 defer.
- **테스트**: `bin/rails test` — **459 runs, 1572 assertions, 0 failures, 0 errors, 0 skips**(회귀 +2, 보안 sink 방어 포함). grep — 금지 라벨·원시 색·인라인 스타일 부재.
- **Epic 6 완료**: 6.1~6.7 전 화면 done — 표현 계층(대시보드/인기/경쟁/콘텐츠갭/저장/설정 + 에버그린 탭) 완성.
