---
title: 'Story 1.2: 인증 제너레이터 + 운영 2인 seed'
type: 'feature'
created: '2026-07-24'
status: 'done'
review_loop_iteration: 0
followup_review_recommended: false
context:
  - '{project-root}/_bmad-output/project-context.md'
  - '{project-root}/_bmad-output/implementation-artifacts/epic-1-context.md'
warnings: []
baseline_revision: 'a1c4ee05d7648f1fa076b4f48421333ade0a6a64'
final_revision: '8e12b417e1da26e83df2f73235ac3952d7df2ba9'
---

<intent-contract>

## Intent

**Problem:** 앱이 아직 인증 없이 열려 있어 내부 도구가 미인증 접근에 노출된다. 운영 2인만 로그인해 쓸 수 있어야 한다.

**Approach:** Rails 8 기본 인증 제너레이터(`bin/rails generate authentication`, AD-14)로 `User`·`Session`·`has_secure_password` 기반 세션 인증을 세우고, 운영 2인을 idempotent seed로 등록한다. 미인증 요청은 로그인 화면으로 리다이렉트되고, 외부 공개 회원가입 폼·멀티테넌시는 두지 않는다. 리다이렉트를 검증할 수 있도록 인증이 걸린 최소 루트(placeholder)를 둔다 — 실제 앱 셸은 Story 1.4가 얹는다.

## Boundaries & Constraints

**Always:**
- Rails 8 표준 인증 제너레이터 산출물을 쓴다(`User`, `Session`, `Current`, `has_secure_password`, `Authentication` concern). 바퀴 재발명 금지.
- 인증은 기본 전면 적용(`require_authentication`) — 미인증 요청은 로그인 화면으로 리다이렉트.
- 운영 2인 seed는 **idempotent**(재실행해도 중복 생성 없음). 이메일·비밀번호는 ENV 재정의 가능하고 dev 기본값은 문서화된 placeholder다.
- 로그인·비밀번호 재설정 페이지만 미인증 접근 허용(제너레이터 기본). 그 외 전면 보호.
- 비밀번호는 `has_secure_password`(bcrypt)로만 저장. 평문 저장·리포 하드코딩 금지.

**Block If:**
- 인증 제너레이터가 `feat/rails-implementation`에서 실행 실패하거나 기존 파일과 해소 불가 충돌을 내는 경우 → HALT.

**Never:**
- 외부 공개 회원가입(registration/sign-up) 라우트·폼. 멀티테넌시·외부 회원 관리.
- OmniAuth·Devise 등 서드파티 인증 젬(Rails 8 기본 제너레이터만).
- 이름/아바타 컬럼·앱 셸·좌측 내비(Story 1.4 소관). 이 스토리 루트는 최소 placeholder에 그친다.
- 실존 인물을 가정한 실명·실이메일을 seed에 하드코딩(placeholder + ENV 재정의).

## I/O & Edge-Case Matrix

| Scenario | Input / State | Expected Output / Behavior | Error Handling |
|----------|--------------|---------------------------|----------------|
| 미인증 접근 | 세션 없음, GET `/` | 로그인 화면(`new_session_path`)으로 302 리다이렉트 | — |
| 인증 접근 | 유효 세션, GET `/` | 200, placeholder 루트 렌더 | — |
| 로그인 | seed 운영자 이메일+비밀번호 | 세션 생성 후 루트 접근 가능 | 오자격 → 로그인 화면 재표시 |
| seed 재실행 | 이미 2 운영자 존재 | 중복 생성 없음(카운트 불변) | — |
| 회원가입 시도 | registration 경로 탐색 | 그런 라우트가 없음 | 404/미정의 |

</intent-contract>

## Code Map

- `app/models/user.rb`·`session.rb`·`current.rb` -- 제너레이터 산출 인증 모델
- `app/controllers/concerns/authentication.rb` -- `require_authentication`·세션 관리(제너레이터 산출)
- `app/controllers/application_controller.rb` -- `include Authentication`(제너레이터가 수정)
- `config/routes.rb` -- `resource :session`·`resources :passwords`·`root` (제너레이터 + placeholder 루트)
- `app/controllers/home_controller.rb` -- 인증 걸린 최소 placeholder 루트(1.4가 대체)
- `db/seeds.rb` -- 운영 2인 idempotent seed
- `test/**` -- 인증 리다이렉트·seed·회원가입 부재 검증

## Tasks & Acceptance

**Execution:**
- [x] `.` -- `bin/rails generate authentication` 실행 후 `bin/rails db:migrate` -- `User`·`Session`·`Current`·`Authentication` concern·세션/비번 컨트롤러·라우트·마이그레이션 생성, primary DB에 users·sessions 테이블. bcrypt 언커멘트 → `bundle install`
- [x] `app/controllers/home_controller.rb` + `app/views/home/index.html.erb` + `config/routes.rb`에 `root "home#index"` -- 인증 걸린 최소 placeholder("SPARTA Content Lab" 한 줄). 1.4가 실제 셸로 대체 -- 리다이렉트 AC를 검증 가능하게 함
- [x] `db/seeds.rb` -- 운영 2인을 `User.find_or_create_by!(email_address:)`로 idempotent 등록. 이메일·비밀번호·표시 대상은 ENV 재정의(`SEED_OPERATOR1_EMAIL` 등), dev 기본값은 문서화된 placeholder(`operator1@sparta.local` 등, 비번 기본은 반드시 교체 안내). `bin/rails db:seed`로 검증 -- 운영 2인 등록 AC
- [x] `test/integration/authentication_flow_test.rb` -- 미인증 GET `/` → 로그인 리다이렉트, seed 운영자로 로그인 후 `/` 200, 회원가입 라우트 부재 -- 시스템 동작 검증
- [x] `test/models/seed_operators_test.rb` -- `Rails.application.load_seed`로 운영 2인 생성·재실행 idempotent(중복 없음) 검증 -- seed 계약 검증

**Acceptance Criteria:**
- Given 인증 제너레이터가 실행된 상태, when 앱에 접근하면, then `User`·세션·`has_secure_password`가 적용되고 미인증 요청은 로그인 화면으로 리다이렉트된다.
- Given seed가 실행된 상태, when 사용자 목록을 보면, then 운영 2인이 등록되어 있고 재실행해도 중복이 없다(목업 아바타 2인과 정합하는 2계정).
- Given 앱 라우트, when registration/sign-up 경로를 찾으면, then 외부 공개 회원가입 폼·멀티테넌시가 없다.
- Given seed 운영자 자격증명, when 로그인하면, then 세션이 생성되고 보호된 루트에 접근할 수 있다.

## Spec Change Log

_(비어 있음.)_

## Review Triage Log

### 2026-07-24 — Review pass
- intent_gap: 0
- bad_spec: 0
- patch: 5: (high 0, medium 4, low 1)
- defer: 0
- reject: 3: (low 3)
- addressed_findings:
  - `[medium]` `[patch]` `db/seeds.rb` [보안] 커밋된 기본 비밀번호가 프로덕션 계정에 쓰일 위험(회원가입 없어 seed 계정=전체 접근면). `Rails.env.local?` 아니면 `SEED_OPERATOR_PASSWORD` 명시 강제(미설정 시 raise, 계정 미생성). 프로덕션 가드 동작 검증.
  - `[medium]` `[patch]` `db/seeds.rb` 두 운영자 이메일 정규화 동일 시 조용히 1명만 생성 → 중단(raise) 가드 추가. ENV set-but-empty(`""`) 크래시·빈 이메일 방지 위해 `.presence` 폴백.
  - `[medium]` `[patch]` `test/integration/authentication_flow_test.rb` 회원가입 부재 검증이 헬퍼 3종 추측에만 의존 → user/registrations/sign_ups 컨트롤러 라우트 열거 + `/sign_up`·`/signup`·`/register`·`/users` POST 프로브로 강화.
  - `[medium]` `[patch]` `test/models/seed_operators_test.rb` 기대 이메일 하드코딩 → seed와 동일 소스(ENV→기본값)에서 파생(CI에 SEED_OPERATOR*_EMAIL 설정 시 오탐 방지).
  - `[low]` `[patch]` `test/integration/authentication_flow_test.rb` 미인증 로그인 화면(`new_session_path`) 200 접근 단언 추가(require_authentication 오적용 → 전면 잠금 역케이스 방어).
- rejected(noise): 재실행 시 비밀번호 미갱신(정상 idempotent 의미론), 단일 공유 비밀번호(내부 부트스트랩 후 각자 재설정), 이메일 변경 시 orphan 계정(의도적 관리 행위).

## Design Notes

seed는 실존 인물을 날조하지 않는다 — ENV 재정의 가능한 placeholder(golden):

```ruby
# db/seeds.rb (발췌)
operators = [
  { key: 1, email: ENV.fetch("SEED_OPERATOR1_EMAIL", "operator1@sparta.local") },
  { key: 2, email: ENV.fetch("SEED_OPERATOR2_EMAIL", "operator2@sparta.local") },
]
default_pw = ENV.fetch("SEED_OPERATOR_PASSWORD", "change-me-in-dev")
operators.each do |o|
  User.find_or_create_by!(email_address: o[:email]) { |u| u.password = default_pw }
end
```

주의 — Rails 8 인증 제너레이터는 로그인(`session`)·비밀번호 재설정(`passwords`)만 만들고 registration은 만들지 않는다 → "공개 회원가입 없음" AC는 제너레이터 기본으로 충족된다. 필드명은 `email_address`(제너레이터 규약). placeholder 루트는 최소로 — 실제 6항목 내비·헤더·아바타 렌더는 Story 1.4.

## Verification

**Commands:**
- `bin/rails db:migrate` -- expected: users·sessions 테이블 생성, 종료 0
- `bin/rails db:seed` -- expected: 운영 2인 생성(재실행 시 중복 없음)
- `bin/rails runner "puts User.count"` -- expected: `2`
- `bin/rails test` -- expected: 전부 통과(신규 + 제너레이터 생성 테스트)
- `bin/rails routes | grep -iE "sign_up|registration|users#new"` -- expected: 매치 없음(공개 회원가입 부재)
- `grep -rInE "password|secret" db/seeds.rb` -- expected: 평문 비밀번호 상수 하드코딩 없음(ENV 경유)

## Auto Run Result

Status: done

**구현 요약** — Rails 8 기본 인증 제너레이터(`bin/rails generate authentication`)로 `User`(email_address)·`Session`·`Current`·`has_secure_password`·`Authentication` concern 기반 세션 인증을 세우고 primary DB에 users·sessions 마이그레이션. `require_authentication` 전면 적용(미인증 → 로그인 리다이렉트), 운영 2인 idempotent seed(ENV 재정의·프로덕션 비밀번호 강제 가드), 인증 걸린 최소 placeholder 루트(`home#index`, 1.4가 대체). 공개 회원가입 없음(제너레이터 기본).

**변경 파일(주요)**
- `db/seeds.rb` — 운영 2인 idempotent + 프로덕션 비밀번호 강제·이메일 distinctness·`.presence` 가드
- `app/controllers/home_controller.rb`·`app/views/home/index.html.erb`·`config/routes.rb`(root) — 최소 인증 루트
- `test/integration/authentication_flow_test.rb`·`test/models/seed_operators_test.rb` — 리다이렉트·로그인 접근·회원가입 부재·seed idempotent 검증
- `config/environments/test.rb` — ActiveJob 어댑터 `:test`(제너레이터 이메일 enqueue 단언용), 큐 DB 격리는 `connects_to`로 유지(AD-12, 주석 명시)
- 그 외 인증 제너레이터 stock 산출물(모델·컨트롤러·뷰·mailer·마이그레이션·fixtures·테스트)

**리뷰 결과** — Blind + Edge Case 병렬. patch 5(보안 1·견고성/테스트 4) 적용, reject 3(정상 idempotent 의미론 등). intent_gap·bad_spec 0. 편차 2건(test.rb 어댑터·schema 재덤프) 검증상 무해.

**검증** — Ruby 3.4.10 / Rails 8.1.3. 26 runs, 105 assertions, 0 failures(1.1 격리 9/37 포함 회귀 없음). db:migrate primary DB만, db:seed 재실행 User.count=2, 회원가입 라우트 없음, 프로덕션 비밀번호 가드 raise 확인.

**잔여 리스크** — seed 기본 비밀번호는 dev/test 전용(프로덕션 ENV 강제). 운영자는 첫 로그인 후 비밀번호 교체 권장. 실제 운영자 이메일은 ENV로 지정.
