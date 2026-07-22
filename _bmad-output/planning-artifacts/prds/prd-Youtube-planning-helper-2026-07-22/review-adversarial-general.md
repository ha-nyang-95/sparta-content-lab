# Adversarial Review — PRD: SPARTA Content Lab

Reviewer stance: cynical/adversarial. Scope: does this PRD do its stated job (§0) of turning confirmed research into *implementable, testable* FR/NFR? I hunted only for failures of that job — not new scope.

## Overall verdict

The PRD is unusually disciplined (glossary, traceability, honest cold-start handling) and most FRs are genuinely testable. But it ships **two contradictions that break the core use case and the core differentiator**, one **quantified NFR that the arithmetic appears to violate**, and several **undefined formulas/thresholds an architect or story-writer will hit a wall on**. The evergreen-candidate rule and the absolute-view-floor-vs-own-channel conflict are not cosmetic — they defeat the vision as written. These must be resolved before downstream work.

Counts: **Critical 2 · High 4 · Medium 5 · Low 3**.

---

## CRITICAL

### C1. Absolute view floor (1,000–5,000) filters out the primary user's own channel
- **Location:** §3 Glossary (절대조회수 하한), FR-6 consequence "절대조회수 하한(기본 1,000~5,000) 미만 영상은 성과 배수 순위에서 기본 제외된다", vs §1 Vision + FR-10.
- **Quote:** FR-6 — "절대조회수 하한(기본 1,000~5,000) 미만 영상은 성과 배수 순위에서 기본 제외." Vision/FR-10 — "소형 채널의 대박이 자기 슬롯에서 드러난다."
- **Failure scenario:** `channel-analysis.md` (confirmed source) measures the *own* channel at 10,200 subs with public views **200–4,100**, and explicitly cites a legitimate high-performer at **1,900 views** ("중앙값 기준 2.25배, 고성과, 맞음"). A default absolute floor of 1,000–5,000 removes that 1,900-view high-performer and most of the channel's public catalogue from the 성과 배수 ranking. The tool built to surface small-channel outliers fairly would, at its default setting, hide the operator's own best content and every genuinely small competitor channel below the floor. The two features (FR-6 fluke-suppression) and the vision (FR-10 fair small-channel comparison) point in opposite directions and the PRD never reconciles them.
- **Suggested fix:** Make the absolute floor **relative to the channel/type baseline** (e.g. floor = max(fixed_small, k × baseline)) rather than a flat 1,000–5,000, or explicitly scope the flat floor to *large* channels only. State the resolution in FR-6 and in Open Question #1, with the own-channel 200–4,100 range as the test fixture.

### C2. Evergreen-candidate rule is undefined and fires on ~half of all old videos
- **Location:** §3 Glossary (에버그린 후보), FR-13 + consequences.
- **Quote:** FR-13 — "업로드된 지 오래됐는데 현재 조회수가 채널 기준선을 넘는 영상을 에버그린 후보로 1일차부터 표시."
- **Failure scenario:** The baseline is defined (Glossary 기준선, FR-5) as the **median** of the channel/type's recent public videos. "현재 조회수가 채널 기준선을 넘는" therefore means 성과 배수 > 1 — and *by definition of a median, ~50% of the channel's videos exceed it*. Combined with "오래됐는데" having **no defined age threshold**, an engineer cannot implement this: half of every channel's back-catalogue qualifies, and "old" is unbounded. The MVP's headline differentiator (에버그린, the thing vendors don't provide) is the least-specified requirement in the document. There is no acceptance bound a story-writer could test against.
- **Suggested fix:** Define both bounds numerically: (a) age threshold (e.g. uploaded > 180 days ago), and (b) a multiple threshold well above 1.0 (e.g. 성과 배수 ≥ 2 while old), not merely "exceeds the median." Add these to FR-13 consequences and Open Questions.

---

## HIGH

### H1. §4.1 quota NFR "3% 미만" appears arithmetically violated, and enumeration cadence is undefined
- **Location:** §4.1 Feature-specific NFR; §9.1 item 1.
- **Quote:** "MVP 현실치(50채널 × 200영상 = 1만 영상)에서 일일 쿼터 사용은 기본 1만 units의 3% 미만이어야 한다." (3% = 300 units)
- **Failure scenario:** A daily view snapshot *requires* `videos.list` over all 10,000 videos = 10,000/50 = **200 units/day** just for stats. If `playlistItems.list` enumeration (to detect new uploads) also runs daily, that adds ~50 channels × 4 calls = **200 units**, total ~400 units = **4% > 3%**. The PRD never pins enumeration to a cadence: FR-4 makes *discovery* (`search.list`) weekly, but FR-2's `playlistItems.list` enumeration has no stated frequency. The quantified NFR is either wrong or depends on an unstated assumption. An architect who schedules daily enumeration blows the stated budget.
- **Suggested fix:** State enumeration cadence explicitly (e.g. `playlistItems.list` weekly, `videos.list` stats daily). Recompute the ceiling; if daily stats alone is 200 units, the honest claim is "~2% steady state, ~4% on enumeration days" — not a flat "3% 미만."

### H2. FR-8 and FR-10 both claim to be *the* default dashboard state — contradiction
- **Location:** FR-8 vs FR-10.
- **Quote:** FR-8 — "기본 정렬은 성과 배수 내림차순이다." FR-10 — "기본 그룹핑이 구독자 밴드 티어이며 … 평면(밴드 없이 전체) 정렬로 토글할 수 있다."
- **Failure scenario:** Is the landing dashboard a **flat list sorted by 성과 배수** (FR-8) or a **band-grouped view** (FR-10) with flat as the toggle? Two FRs assert incompatible defaults for the same primary screen (the one SM-1/SM-7 are measured on). A UX designer and story-writer will implement different screens and both will cite the PRD.
- **Suggested fix:** Pick one default. Likely: default = band-grouped (FR-10), sorted-by-multiple *within* band, with flat sort as toggle — and rewrite FR-8's "기본 정렬" to "정렬 키" so it doesn't also claim default layout.

### H3. Opportunity Score (FR-21) has no defined normalization — components are unbounded, output is 0–100
- **Location:** FR-21, §3 Glossary (기회 점수), Open Question #2.
- **Quote:** "성과 배수 신호·경쟁 공통성·콘텐츠 갭·최신성을 가중 합산한 기회 점수(0~100)."
- **Failure scenario:** Weights being TBD is honestly flagged (OQ#2, [ASSUMPTION]). But the harder gap is silent: 성과 배수 is **unbounded** (can be 25x+), 콘텐츠 갭 is a **4-way category**, 최신성 is a **date**, 경쟁 공통성 is a **count**. To weight-sum them into 0–100 each must first be normalized to a common scale, and *no normalization method is specified*. An architect cannot build "가중 합산 → 0~100" from four incommensurable inputs without inventing the mapping — which is exactly what §0 says this PRD should have pinned.
- **Suggested fix:** Specify per-component normalization to [0,1] (e.g. 성과 배수 → min(multiple/10, 1) or percentile rank; 콘텐츠 갭 → fixed 0/0.33/0.66/1 per bucket; 최신성 → decay function). Then weighted sum × 100. Add to FR-21 consequences.

### H4. Baseline built from *recent* (young, low-view) videos systematically inflates old-video multiples — disclosed bias understates its own mechanism
- **Location:** FR-5 (기준선 = 최근 N개 공개 영상 중앙값), FR-24 (편향 명시), §9.1 item 5.
- **Quote:** FR-5 — "기준선 표본은 채널·유형별 최근 N개 공개 영상." FR-24 — "성과 배수가 현재 누적 조회수 기준임을 UI에 명시."
- **Failure scenario:** When scoring an *old* high-view video, its numerator (large cumulative views) is divided by a baseline computed from *recently uploaded* videos that are still young and low-view. This structurally inflates old videos' multiples — the same direction as the disclosed 시점 정합 편향, but caused by the baseline construction, not just cumulative-view drift. FR-24 discloses "old videos look favorable" but attributes it only to cumulative counting; the recent-N baseline choice compounds it and is never acknowledged. This directly poisons FR-13 evergreen detection (which relies on old-video-exceeds-baseline). Uncertainty smoothed over.
- **Suggested fix:** Either compute the baseline over videos of comparable age/maturity, or state explicitly in FR-5 that the recent-N baseline amplifies old-video multiples and that evergreen/old-video scoring inherits this. Don't let FR-24 imply the bias is only from cumulative counting.

---

## MEDIUM

### M1. FR-16 cross-references the wrong FR (traceability bug)
- **Location:** FR-16 consequence.
- **Quote:** "경쟁 채널 동향 위젯이 채널명·구독자 수·**구독자 증감(FR-18)**을 표시한다."
- **Failure scenario:** 구독자 증감 is defined in **FR-22**, not FR-18. FR-18 is 콘텐츠 갭 분포. A story-writer following the reference lands on the wrong requirement. Also note FR-22 is *conditional* (only large channels; small = "측정한계") — FR-16 must inherit that condition, which the wrong pointer obscures.
- **Suggested fix:** Change "(FR-18)" → "(FR-22)" and note the conditional display.

### M2. FR-17 assumes titles never change ("제목 불변"); embeddings are never refreshed
- **Location:** FR-17 consequence.
- **Quote:** "임베딩은 영상당 1회만 생성된다(제목 불변)."
- **Failure scenario:** YouTube titles are frequently edited/A-B tested by creators. If a competitor renames a video, its embedding (and thus 자사 유사영상 / 주제 묶기 / 콘텐츠 갭 results) goes stale forever, since regeneration is explicitly one-time. The cost argument (§9.2, "신규 영상만 과금") relies on this, so the assumption is load-bearing for both correctness and cost — and it is false in the general case.
- **Suggested fix:** Regenerate embedding when a stored title changes on re-collection (still cheap — only changed rows). State it in FR-17 and §9.2.

### M3. FR-20 topic clustering has no method or threshold
- **Location:** FR-20.
- **Quote:** "§4.7과 같은 임베딩을 재사용해 영상을 주제 단위로 자동 묶는다."
- **Failure scenario:** "자동 묶기" names no algorithm (threshold clustering? k-means? connected components over cosine ≥ τ?) and no τ. FR-17 at least says the similarity threshold is tuned on labeled pairs; FR-20 gives nothing. The recommendation engine (FR-19) depends on these clusters. An architect must invent the clustering contract.
- **Suggested fix:** Specify the clustering approach and its threshold source (reuse FR-17's tuned τ for edge formation + connected components, or state otherwise).

### M4. FR-19 has no defined behavior when fewer than 3 topics qualify or scores tie
- **Location:** FR-19 ("주제 3개").
- **Failure scenario:** During cold start or a thin week, the pipeline may yield 0–2 qualifying topics; opportunity scores may tie at the cutoff. The FR hard-asserts "3개" with no lower-bound handling, no tie-break rule, no "fewer available" state. SM-2 measures "매주 … 3개" as success — so undefined behavior here directly threatens a Primary success metric.
- **Suggested fix:** Define fallback (pad with next-best candidates / show "N available this week"), and a deterministic tie-break (e.g. higher 성과 배수, then recency).

### M5. Cold-start "충분히 쌓인" / "D+n" flip thresholds are never quantified per widget
- **Location:** FR-3, FR-12, FR-14, FR-23; Glossary (에버그린 2~3주).
- **Quote:** FR-23 — "스냅샷이 충분히 쌓이기 전까지 'D+n 데이터 수집 중'." FR-14 — "충분히 쌓인 뒤(수 주)."
- **Failure scenario:** Each time-series widget flips from "수집 중" to live at some snapshot count, but the count is only vaguely stated ("수 주", "2~3주") and never fixed per widget (sparkline needs ~7 snapshots, VPD ≥2, evergreen promotion ~14–21). FR-23 promises per-widget granularity but gives no per-widget thresholds. A story-writer can't write the flip condition.
- **Suggested fix:** Tabulate the minimum snapshot count that flips each widget (sparkline, VPD, verified evergreen, subscriber delta).

---

## LOW

### L1. FR-2 collects likeCount/commentCount that no FR consumes (dead data / minor scope creep)
- **Location:** FR-2. Collects 좋아요·댓글, but no scoring/display FR uses them. Either wire them to a requirement or drop from the collection spec to avoid implying unbuilt features.

### L2. FR-1 retry-on-failure vs "하루 1회 상한" tension
- **Location:** FR-1 — "지수 백오프로 재시도" and "갱신 주기 상한은 하루 1회." Same-day retries after a failure are arguably a second run that day. Harmless if intended, but state that retries of a failed run don't count against the once-daily cap.

### L3. FR-3 90-day daily→weekly rollup loses resolution for long-horizon evergreen verification
- **Location:** FR-3 vs FR-14. Weekly rollup after 90 days coarsens the age/view curve; multi-month evergreen verification loses daily granularity. Fine for the "2~3주" promotion window, but note the limit so later long-horizon analysis isn't assumed available.

---

## Notes on what the PRD does well (so fixes don't regress it)
- Honest cold-start separation (FR-23, day-1 vs time-series) is genuinely good — don't collapse it into one banner.
- The 중앙값-not-평균 and 쇼츠/롱폼 분리 decisions are grounded in measured own-channel data (`channel-analysis.md`) — keep the fixtures.
- [ASSUMPTION]/Open-Question tagging is disciplined; the failures above are mostly places that *should* have carried the same tags but were stated as settled.
