<!-- 아키텍처 스파인의 확정 스택·AD 규칙에 대한 기술 최신성(technology-currency) 리뷰 -->
---
review_type: technology-currency
target: ARCHITECTURE-SPINE.md (SPARTA Content Lab)
reviewer: technology-currency reviewer
date: '2026-07-22'
web_verified_on: '2026-07-22'
verdict: PASS_WITH_ONE_FIX
---

# 기술 최신성 리뷰 — SPARTA Content Lab 아키텍처 스파인

## 한 줄 판정

스택은 전반적으로 실재하고 현행이며 워크로드에 적합하다. **단 하나의 실질 수정**이 필요하다 — Stack 표의 `Tailwind CSS 3.x`와 AD-15/소스트리의 `config/tailwind.config.js` + `theme.extend` 서술이 현행 `tailwindcss-rails`(4.x, Tailwind CSS v4 기본)의 설정 방식과 어긋난다. 데이터·파이프라인 레이어(Rails 8·Solid Queue·SQLite·YouTube API·임베딩·sqlite-vec)는 전부 확인 완료로 통과.

방법 — 인용 연구(2026-07-21 웹검증)가 이미 소스로 확정한 사실은 재심리하지 않고 확정으로 취급했다. Stack 표에 적힌 버전과 시점 민감 항목만 2026-07-22 웹으로 재확인했다.

---

## 항목별 검증

### 1. Ruby on Rails 8.x — ✅ 확정, 적합

레이어드 + 파이프-필터, 서버 렌더 ERB, 인프로세스 배치 워크로드에 정확히 맞는 선택. Rails 8은 현행 메이저이고 아래 4·5·6번(Solid Queue·인증·멀티DB) 기능이 모두 8에서 기본 제공된다. 문제 없음.

### 2. Solid Queue — ✅ 확정 (연구 B-1에서 소스 확인, 재확인 완료)

- Rails 8의 **기본 Active Job 백엔드**가 맞다(프로덕션 어댑터로 기본 설정). Redis 불필요, SQL 백엔드(SQLite 포함)로 동작. `FOR UPDATE SKIP LOCKED`를 지원되면 활용.
- 반복 작업은 `config/recurring.yml`로 선언 — 확인됨. (설치 시 `config/queue.yml` + `config/recurring.yml` + `db/queue_schema.rb`가 함께 생성된다. 스파인은 `recurring.yml`만 언급하는데, 누락이 아니라 요약이므로 문제 아님.)
- AD-11(수집·발굴을 분리된 Solid Queue recurring으로) — 메커니즘상 타당. **단 주의:** Solid Queue 스케줄러/워커 프로세스가 상시 떠 있어야 recurring이 발화한다(`bin/jobs` 또는 Puma의 `solid_queue` 플러그인 인프로세스). Deferred §"배포·환경 상세"에 이미 인지되어 있으므로 스파인 결함 아님. 근거 재확인.

> 출처: [rails/solid_queue README](https://github.com/rails/solid_queue/blob/main/README.md), [Saeloun: Rails 8 Solid Queue](https://blog.saeloun.com/2026/05/26/rails-8-solid-queue-database-backed-active-job/)

### 3. Solid Cache — ✅ 확정, 별도 DB 파일 기본 정합

Rails 8이 SQLite로 `rails new` 시 `database.yml`에 primary/cache/queue(/cable)를 별도 DB로 분리 생성하는 것이 기본이다. AD-12(앱/큐/캐시 3개 SQLite 파일 분리)와 정합. 문제 없음.

### 4. SQLite 3.x (WAL, 멀티DB) — ✅ 확정 (연구 B-2에서 소스 확인)

- Rails 8은 SQLite에 기본으로 `journal_mode=WAL`, `synchronous=NORMAL`, `busy_timeout` 등을 켠다 — 확인됨. AD-12의 "WAL + busy_timeout 5000ms (Rails 8 기본)" 정합.
- 멀티DB(별도 파일 분리)도 Rails 8 기본. 단일 라이터/배치 트랜잭션 짧게 유지 권고도 SQLite 특성과 정합. 문제 없음.

### 5. `bin/rails generate authentication` — ✅ 확정, AD-14 정합

Rails 8에 **실재하는 내장 제너레이터**다. `User`(`has_secure_password`) + `Session` 모델 + 세션 컨트롤러 + 비밀번호 재설정 + 마이그레이션 + 라우트를 생성하고, 세션을 암호화 쿠키에 저장한다. AD-14의 서술(`User`·세션·`has_secure_password`, 운영 2인 seed)과 정확히 일치. `[ADOPTED]` 표기 타당.

> 출처: [Saeloun: Rails 8 authentication generator](https://blog.saeloun.com/2025/05/12/rails-8-adds-built-in-authentication-generator/), [BigBinary: auth generator](https://www.bigbinary.com/blog/rails-8-introduces-a-basic-authentication-generator)

### 6. YouTube Data API v3 + 2026-06-01 쿼터 변경 — ✅ 확정 (연구 A-2에서 공식 개정이력 확인, 재확인 완료)

- `search.list`가 **별도 버킷(하루 100콜, 콜당 1 unit)**으로 분리된 것 — 2026-07-22 현재 여전히 정확. 제3자 문서도 "search는 자체 일일 버킷, 공유 1만 풀과 분리"로 수렴 확인.
- `videos.list` / `channels.list` / `playlistItems.list` = 콜당 1 unit(part 무관) — 확인. AD-1의 쿼터 회계(공유 1만 + search 별도 100콜/일, 배치 50)와 AD-11 파이프라인 정합. 문제 없음.

> 출처: [YouTube Data API Overview/getting-started](https://developers.google.com/youtube/v3/getting-started), [search.list](https://developers.google.com/youtube/v3/docs/search/list)

### 7. gemini-embedding-001 (유료 결제) — ✅ 확정, 적합

- 모델 실재하며 GA 상태, 현행. 정가 **$0.15 / 1M 토큰**(배치 $0.075) — 확인.
- **유료 티어 존재**하며 프로덕션은 유료 전제라는 스파인 가정이 옳다. 임베딩은 여전히 무료 티어도 있으나(연구 F-4), "장기 운영 도구는 무료 티어에 세우지 않는다 → 유료·지출상한"이라는 판단은 2026-07 현재도 유효. Stack의 "현행 (유료 결제)" 표기 적절.
- AD-10(영상당 1회 생성, `embedding_source_hash` 변경분만 재생성)이 F-5 비용 모델과 정합. 문제 없음.

> 출처: [Gemini API pricing](https://ai.google.dev/gemini-api/docs/pricing), [Gemini Embedding GA 발표](https://developers.googleblog.com/gemini-embedding-available-gemini-api/)

### 8. sqlite-vec (미채택, 5만 벡터 초과 시 전환) — ✅ 확정, 판단 합리적

- 실재·유지 중. 최신 stable 0.1.9(2026-03-31), 프리릴리스 0.1.10.alpha.4(2026-05-18) — 연구 F-2 시점과 일치, 여전히 활성.
- AD-10의 "N≈500~수만 규모에선 Ruby 코사인(BLOB), 5만 벡터 초과 시 sqlite-vec 드롭인 전환" 판단은 합리적이다. 벡터는 매일이 아니라 신규 영상 시에만 증가하므로 임계 도달이 느리고, 네이티브 확장 컴파일·배포 리스크를 MVP에서 회피하는 근거가 타당. 다만 sqlite-vec는 여전히 0.1.x(pre-1.0)라 향후 전환 시점에 API 안정성을 재확인할 것 — 지금 채택 항목이 아니므로 스파인 결함 아님.

> 출처: [asg017/sqlite-vec releases](https://github.com/asg017/sqlite-vec/releases), [sqlite-vec Ruby 문서](https://alexgarcia.xyz/sqlite-vec/ruby.html)

---

## ⚠️ 수정 필요 — Tailwind 버전·설정 방식 불일치 (MEDIUM)

**위치:** Stack 표(`Tailwind CSS | 3.x (tailwindcss-rails)`), AD-15, 소스트리(`config/tailwind.config.js`).

**문제.** 현행 `tailwindcss-rails` gem의 메이저는 **4.x**(4.3.0, 2025-07 등)이고, 이는 **Tailwind CSS v4를 기본**으로 설치한다. Tailwind v4부터는 `tailwind.config.js`가 필요 없고 설정이 메인 CSS 파일(`@theme`)로 이동했다. 스파인은 세 곳에서 v3 세계관을 전제한다.

1. Stack 표가 `Tailwind CSS 3.x`로 못박음 — `rails new --css=tailwind` 또는 최신 gem 설치 시 실제로 깔리는 것은 v4다.
2. AD-15: "DESIGN.md §10 토큰을 `config/tailwind.config.js`의 `theme.extend`로 이관" — 이건 v3 JS-config 방식. v4에서는 CSS `@theme { --color-primary-600: #1145DD; ... }`로 이관해야 한다.
3. 소스트리에 `config/tailwind.config.js`를 못박음 — v4 기본 셋업엔 이 파일이 없다.

**영향.** UI 토큰 매핑 레이어에 국한(데이터·파이프라인 무관). 그러나 DESIGN.md가 색·간격·radius의 단일 원천이고 이 리뷰 프로젝트의 CLAUDE.md 규칙(원시 Tailwind 색 금지, §10 매핑 토큰만)이 바로 이 이관 메커니즘에 의존하므로, 6화면을 짜기 전에 "토큰을 어디에 어떤 문법으로 넣는가"가 확정돼야 한다. 지금 상태로 두면 세션마다 v3 `theme.extend`와 v4 `@theme` 사이에서 추정이 갈릴 수 있다 — 스파인이 막으려는 바로 그 드리프트.

**권고 (택1, 운영자 결정):**
- **(A) v4 채택(권장·기본흐름):** Stack을 `Tailwind CSS 4.x (tailwindcss-rails)`로, AD-15/소스트리를 CSS `@theme` 기반으로 갱신. `config/tailwind.config.js` 대신 `app/assets/stylesheets/application.tailwind.css`(또는 v4 진입 CSS)에 `@theme` 블록으로 §10 토큰 정의. 최신 기본 경로라 마찰이 가장 적다.
- **(B) v3 의도적 고정:** `tailwindcss-ruby`를 `~> 3`으로 핀 고정하고 스파인에 "v4 기본을 의도적으로 보류(JS-config 유지)"를 명시. 이 경우 현재 서술은 그대로 유효하되, "3.x"가 실수 아닌 의도임을 문서에 남겨야 한다.

어느 쪽이든 **Stack 표·AD-15·소스트리 세 곳을 같은 버전으로 정합**시키는 것이 핵심. 지금은 "3.x"라고만 적혀 있어 v4가 기본인 현실과 어긋난 채 v3 설정 문법을 전제한다.

> 출처: [rails/tailwindcss-rails releases](https://github.com/rails/tailwindcss-rails/releases), [Greg Molnar: TailwindCSS and Rails 8](https://greg.molnar.io/blog/tailwindcss-and-rails-8/), [DEV: Setting up Tailwind in Rails 8](https://dev.to/jmhooper/setting-up-tailwind-css-in-a-new-rails-app-3g2g)

---

## 종합

| 항목 | 판정 | 비고 |
|---|---|---|
| Ruby on Rails 8.x | ✅ 현행·적합 | — |
| Solid Queue (recurring, SQLite) | ✅ 확정 | 기본 백엔드·recurring.yml 확인. 스케줄러 상시 프로세스 필요(이미 인지) |
| Solid Cache (별도 DB) | ✅ 확정 | 멀티DB 기본 정합 |
| SQLite 3.x (WAL, 멀티DB) | ✅ 확정 | Rails 8 기본 WAL+busy_timeout 정합 |
| `generate authentication` | ✅ 확정 | User+Session+has_secure_password 정확 |
| YouTube Data API v3 (2026-06-01 쿼터) | ✅ 확정 | search 별도 100콜/일, 1-unit 조회 정확 |
| gemini-embedding-001 (유료) | ✅ 확정 | GA·$0.15/1M·유료 전제 타당 |
| sqlite-vec (미채택) | ✅ 확정 | 0.1.x 활성, 전환 임계 판단 합리적 |
| **Tailwind CSS `3.x` + tailwind.config.js** | ⚠️ **불일치** | gem 현행 4.x=Tailwind v4(=CSS `@theme`, JS config 없음). Stack·AD-15·소스트리 3곳 정합 필요 |

시점 민감 사실(YouTube 쿼터 개편, Gemini 무료 티어 축소, sqlite-vec 버전)은 인용 연구가 이미 소스로 확정했고 2026-07-22 재확인에서 변동 없음. 유일한 실질 조치는 Tailwind 버전·설정 방식 정합이며, 데이터/파이프라인 아키텍처의 불변식에는 영향이 없다.
