<!-- omd:managed:start — DESIGN.md 토큰 shim. 이 블록은 DESIGN.md 변경 시 omd:sync로 갱신된다. 손으로 고치지 말 것(고칠 값은 DESIGN.md에서). -->
# 디자인 규칙 (SPARTA Content Lab)

이 프로젝트의 모든 UI 작업은 **`DESIGN.md`** 의 토큰을 단일 원천으로 쓴다. 화면 6개(대시보드 / 인기 콘텐츠 / 경쟁 채널 / 콘텐츠 갭 / 저장한 영상 / 설정)가 서로 다른 세션에서 만들어지므로, 색·간격·radius를 세션마다 추정하면 화면이 어긋난다. 아래 요약은 편의용이고 **권위는 `DESIGN.md` 전문**에 있다.

**핵심 토큰 (실측: `Planning/목업 샘플.png`)**
- Primary 블루 `#1145DD` (`primary-600`) — 내비 활성·번호 뱃지·활성 탭·기본 버튼·링크·기회 점수.
- Success 그린 `#159C49` (`success-600`) — 성과 배수·증가율.
- 캔버스 `#FBFCFD` · 서피스 `#FFFFFF` · 보더 `#E5E7EB` · divider `#EEF1F5`.
- 텍스트: strong `#111827` · body `#374151` · muted `#6B7280` · subtle `#9CA3AF`.
- 뱃지: neutral `#F2F4F7`/`#4B5563` · caution `#FEF1E3`/`#F56B04` · danger `#FEEEEF`/`#C31334`.
- Radius: 카드 12px · 컨트롤 8px · 칩 6px. 카드 패딩 24px, 그리드 gap 20px.
- 폰트: `Pretendard, "Noto Sans KR", "Noto Sans JP", system-ui, …` — 한·일 글리프 동시 커버. 숫자 `tabular-nums`.

**성과 배수 색 밴드 (PRD FR-8, 전 화면 동일)** — 순차 그린 램프
- `<2배` 중립(muted 텍스트) · `2~5배` `#15803D`/bg`#E7F6EC` · `5~10배` `#0F7A38`/bg`#C6EBD1` · `>10배` 흰 텍스트/bg`#159C49`(solid). amber/red는 성과 배수에 쓰지 않는다.

**필수 규칙**
1. 원시 Tailwind 색(`blue-600` 등) 직접 사용 금지 — `DESIGN.md` §10 매핑 토큰만.
2. 라벨 정합(강제): "구독자 대비 조회수" → **"성과 배수(채널 평소 대비)"** (PRD §11).
3. 정직성 상태(데이터 수집 중 / 측정한계 / 에버그린 후보 vs 검증 / 검증 요망 / 저신뢰)는 `DESIGN.md` §4.7 스타일로. 위젯 숨기지 말고 자리 유지.
4. 다국어(한·일 혼재 제목): `DESIGN.md` §7 — 폰트 폴백·`word-break:keep-all`·line-clamp/truncate·`min-w-0`·`title` 툴팁.
5. 반응형: 좌측 내비 모바일 축소, 테이블 가로 스크롤(`DESIGN.md` §5). 본문 가로 스크롤 금지.
6. 목업과 다르게 가고 싶으면 임의 변경 말고 운영자에게 묻는다.
<!-- omd:managed:end -->
