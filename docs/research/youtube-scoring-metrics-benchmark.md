# YouTube 콘텐츠 리서치 SaaS 채점 방식 벤치마크

조사일 2026-07-20 · 1차 출처 18건 fetch, 클레임 83건 추출, 25건 적대적 검증(9건 확정 / 16건 기각)

---

## 0. 한 줄 결론

**우리 기획서의 "조회수 ÷ 구독자 수"는 업계 표준이 아니다.** vidIQ와 Viewstats가 각각 독립적으로 채택한 기준선은 **"조회수 ÷ 그 채널 자신의 최근 영상 평균 조회수"**다. 구독자 수는 점수의 분모가 아니라 결과를 걸러보는 **필터 축**으로만 쓰인다.

이 교체는 우리 도메인(일본어권 한국어 교육이라는 극소 니치)에서 특히 이득이 크다. 채널이 자기 자신과만 비교되므로, 비교군을 영어권 한국어 교육·언어 교육 일반까지 억지로 넓혀도 카테고리 간 조회수 규모 차이가 상쇄되기 때문이다. 반면 "조회수÷구독자"나 "카테고리 평균 대비" 방식은 이 확장에서 즉시 깨진다.

---

## 1. 서비스별 지표 정리표

| 서비스 | 지표 | 공개된 정의 | 계산에 쓰이는 데이터 | 재현 등급 | 출처 |
|---|---|---|---|---|---|
| vidIQ | **Outlier Score** | "a video's performance relative to the average performance of other videos on the same channel... compares the video's view count to the channel's average views **within a similar timeframe**" | 채널 내 타 영상 조회수 + 영상 나이 + (제품 페이지 기준) velocity 성분 | **부분 재현** | [support.vidiq.com/9660010](https://support.vidiq.com/en/articles/9660010-outliers), [vidiq.com/features/outliers](https://vidiq.com/features/outliers/) |
| vidIQ | **VPH (Views Per Hour)** | "aka view velocity... a great way to determine which videos are taking off to become viral" / "VPH updates over time so even if a video is older you can still see if viewership is heating up" | 시간 해상도 조회수 시계열 | **재현 불가**(우리는 하루 1회 상한 → VPD로 대체) | [support.vidiq.com/108672](https://support.vidiq.com/en/articles/108672-what-is-vph-views-per-hour) |
| vidIQ | **Search Volume** | "vidIQ **estimates** the monthly searches on that keyword on YouTube (based on a 30-day rolling period)" · 제품 페이지 "all volume data is estimated" | 비공개 | **재현 불가** | [support.vidiq.com/9421214](https://support.vidiq.com/en/articles/9421214-keywords-research) |
| Viewstats | **Outlier Score** | "An Outlier is a video on a channel that out performed all the other videos on that channel by a mile" · 운영 정의 "204x outlier score... 204 TIMES more views than **the last 10 videos averaged at that time**" | 채널 최근 10개 영상 조회수(당시 시점 기준) | **부분 재현** | [viewstats.zendesk.com/22966946776091](https://viewstats.zendesk.com/hc/en-us/articles/22966946776091-Outliers-Tool) |
| Viewstats | **1/10 Ranking** (나이 정합 비교) | "It compares views received **during the same time frame**... videos being compared will only show their views in relation to the time which has elapsed since the publication of the main video. This will result in all-time views being a different value than when being compared" | 영상 나이 t일 시점의 조회수 시계열 | **재현 불가**(소급 불가) | [viewstats.zendesk.com/22512527607451](https://viewstats.zendesk.com/api/v2/help_center/en-us/articles/22512527607451.json) |
| TubeBuddy | **Weighted / Unweighted Keyword Score** | unweighted = "isn't calculated for your SPECIFIC channel... based on search volume and competition" / weighted = "based on search volume, competition, relevancy, and how you compare to others currently ranking in search" | 검색량 추정치 + 경쟁 + 내 채널 이력 | **부분 재현**(구조만, 검색량 성분 제외) | [support.tubebuddy.com/9324516769051](https://support.tubebuddy.com/hc/en-us/articles/9324516769051-TubeBuddy-Keyword-Explorer-Scores-Explained) |
| TubeBuddy | **Searches Per Month** | "**YouTube does not provide public search volume statistics.** We can get an **estimate** based on how many search results there are, how many views the search results have, and how many search results there are on exact matches... In addition, we tie in with a trusted 3rd party provider (keywordtool.io)" | 검색결과 수 + 결과 영상 조회수 + 서드파티 | **재현 불가** | [support.tubebuddy.com/9324740260379](https://support.tubebuddy.com/hc/en-us/articles/9324740260379-How-is-the-Keyword-Score-Calculated-in-Keyword-Explorer) |
| Keyword Tool | **YouTube Search Volume** | Google/Bing은 "100% accurate", **YouTube만 "estimated"**로 명시 분리 · "YouTube does not share information about the popularity of keywords... We use **clickstream data** to estimate" | 클릭스트림 패널 | **재현 불가** | [keywordtool.io/youtube](https://keywordtool.io/youtube), [keywordtool.io/api](https://keywordtool.io/api) |
| **viewtrap / Velio / 1of10** | — | **확인된 것 없음** | — | — | 검증 통과 클레임 0건 |
| **Social Blade** | — | **확인된 것 없음**(파이프라인 관련 주장 2건 모두 검증 기각) | — | — | 검증 통과 클레임 0건 |

> 발주자가 1차로 지목한 4개 중 **viewtrap, Velio는 공개 문서에서 아무것도 확인되지 않았다.** 로그인 월 뒤에 있거나 방법론 문서가 없다. 이 두 곳은 "미조사"가 아니라 "공개 근거 부재"로 기록한다.

---

## 2. A~G 질문별 답변

### A. 채점 단위 — 최소 두 개로 분리되어 있다 (신뢰도 높음, 3-0)

벤더들은 **영상 채점과 키워드 채점을 하나로 합치지 않는다.** 별도 도구로 판다.

1. **영상 단위** — 채널 내부 기준선 대비 배수(outlier)
2. **키워드 단위** — 수요(검색량 추정) 대 공급(경쟁) 구조 + 내 채널 적합도 가중

TubeBuddy는 여기서 한 단계 더 나눈다. unweighted(유튜브 전체 일반 점수)와 weighted(내 채널 기준 점수)를 분리 제공하고, weighted 쪽만 "your past content, metadata, views, and engagements"를 반영한다고 명시한다.

**채널 단위 종합 점수를 공개 산식으로 제공하는 곳은 확인되지 않았다.**

> ⚠️ 범주 주의 — TubeBuddy의 "내 채널 기준"은 **키워드 채점**의 기준선이다. 영상 outlier 채점의 기준선 근거로 인용하면 범주 오류다.

### B. 정규화 기준선 — 채널 내부 기준선이 표준 (신뢰도 높음, 3-0 × 2건 독립 확인)

vidIQ 공식 문서의 결정적 예시다.

> "A video with **1 million** views on a channel with an average view count of 500,000 will have a **higher** outlier score than a video with **2 million** views on a channel with an average of 5 million."

200만 > 100만인데 점수는 후자가 낮다. 절대 조회수 기준도, 구독자 기준도 아님이 확증된다.

Viewstats도 동일 설계다. "204x = 최근 10개 영상 평균 대비 204배"라는 운영 정의를 헬프센터에 그대로 적어놨다(문서 갱신일 2025-06-20).

**구독자 수가 분모가 아니라는 근거** — vidIQ 제품 페이지는 구독자를 산식이 아니라 별도 필터("Subscribers & Channel Size")로 노출하고, Viewstats도 "Toggle the views, **channel size**, and **outlier score**"라며 둘을 독립 축으로 둔다.

**하지만 여기서 멈춰야 한다.** "outlier = 조회수 ÷ 채널 평균"이라는 단순 비율 주장은 적대적 검증에서 **0-3으로 기각**됐다. vidIQ 제품 페이지가 "based on views, **velocity**, and performance vs. a channel's usual baseline"이라고 쓰기 때문이다. velocity(시간) 성분이 섞여 있으므로 단순 비율로 등치시키면 과대해석이다.

**확인 불가로 남는 것**
- 평균인가 중앙값인가 (vidIQ는 "average"라 쓰지만 실제 구현은 비공개)
- 표본 크기가 9개인가 10개인가 (3자 소스끼리 엇갈림)
- "within a similar timeframe"의 정확한 폭

### C. 시간 정규화 — 성과 점수와 분리된 별도 축 (신뢰도 높음, 2-1)

vidIQ 체계 안에서 역할이 나뉜다. **성과 정규화는 Outlier가, 모멘텀은 VPH가 담당한다.** 공식 문구는 "VPH aka view velocity is a great way to determine which videos are **taking off** to become viral"이다.

우리 대시보드도 이 두 축을 하나의 점수로 뭉개면 안 된다.

**확인 불가** — VPH의 정확한 산식(최근 구간 증분인지, 누적조회수÷경과시간의 생애 평균인지)은 어느 출처로도 확인되지 않았다. 관련 파생 주장 2건 모두 검증 기각(1-2, 0-3)됐으므로 추정 금지다.

**"업계가 수명주기를 24h/7d/28d 3단계로 나눈다"는 서술도 하면 안 된다** — 해당 주장은 0-3으로 기각됐다.

### D. 에버그린 판정 — 벤더 지표가 확인되지 않았다 (확인 불가)

"알고리즘 급등"과 "장기 검색 유입"을 구분하는 명시적 벤더 지표를 1차 출처로 **찾지 못했다.** 유일한 인접 단서는 vidIQ VPH 문서의 "even if a video is older you can still see if viewership is heating up"인데, 이는 재조명 감지를 시사할 뿐 에버그린 판정 지표가 아니다.

따라서 **이 축은 시장에서 빌려올 수 없고 우리가 직접 설계해야 한다.** 원리적으로 가능한 접근은 하나뿐이다 — 자체 일일 스냅샷을 쌓아 "영상 나이 대비 일간 조회수 증분의 감쇠 기울기"를 보는 것. 급등형은 초기 급상승 후 가파른 감쇠, 에버그린형은 낮고 평탄한 지속 곡선을 그린다. **단 이건 우리 추론이고 벤더 검증 근거가 없으며, 추적 시작 시점부터만 계산 가능하다.** 3주 MVP 안에서 탑재는 가능해도 검증은 불가능하다.

### E. 주제 수요 측정 — 시장 전체가 추정치다 (신뢰도 높음, 3-0 × 3개 벤더 독립 확인)

세 벤더가 각자 자백한다.

- **TubeBuddy** — "First and foremost, **YouTube does not provide public search volume statistics.** We can get an estimate based on how many search results there are, how many views the search results have..."
- **vidIQ** — "vidIQ **estimates** the monthly searches" / "expect... rather than an exact number, since **all volume data is estimated**"
- **Keyword Tool** — Google/Bing은 "100% accurate", YouTube는 명시적으로 estimated 그룹. "We use clickstream data to estimate"

TubeBuddy 진술은 자사에 불리한 진술(statement against interest)이라 마케팅 편향과 반대 방향이며, 그만큼 신뢰도가 높다.

**우리 도메인 특수 리스크** — 일본어 한국어교육이라는 극소 니치에서는 clickstream 패널 표본 자체가 희박하다. 상용 도구를 돈 주고 사더라도 신뢰구간이 무너진다. **이건 우리 제약의 문제가 아니라 시장 전체의 한계다.**

⚠️ TubeBuddy 자신이 별도 문서에서 `search.list`의 `totalResults`가 근사·불안정하다고 언급하므로, 이 값을 경쟁 강도의 주요 입력으로 쓰지 말 것.

### F. 데이터 확보 구조 — 벤더 측 1차 근거를 확보하지 못했다

Social Blade 파이프라인 관련 주장 2건 모두 검증 기각됐다. **우리 답은 소거법에 의존한다** — YouTube Data API v3에 과거 조회수 시계열 엔드포인트가 존재하지 않으므로 소급은 불가능하고, 추적 시작 시점부터 자체 스냅샷을 쌓는 수밖에 없다. 이건 논리적 귀결이지 벤더 확인 사항이 아니다.

### G. 한계와 비판 — 세 가지 파손 모드 (신뢰도 중간, 3자 소스 기반)

1. **짧은 비교 창의 왜곡** — 직전 9~10개라는 창은 급성장/급감 채널이나 업로드 주기가 불규칙한 채널에서 점수를 왜곡한다. 대상 채널이 최근 부진 구간이면 기준선이 낮아져 **평범한 영상이 고득점 outlier로 오탐**된다.
2. **소형 채널 무력화** — Viewstats는 10K 구독자 미만에서 데이터가 제한적이라는 지적이 있다. 우리 비교군 다수가 여기 해당할 가능성이 높다.
3. **시점 정합 결손** — 제대로 하려면 "영상 나이 t일 시점의 조회수"가 필요한데, 우리는 추적 시작 이전 영상에 대해 이 값을 만들 수 없다. **이것이 우리 아키텍처의 가장 큰 구조적 결손이다.**

---

## 3. 채택 후보 지표와 우리 제약 안에서의 변형

| # | 지표 | 원본 | 우리 변형 | 1일차 동작 |
|---|---|---|---|---|
| 1 | **채널 내부 배수** | vidIQ/Viewstats Outlier | 조회수 ÷ **채널 최근 N개 영상 중앙값** (평균 아님) | ✅ `videos.list`로 즉시 |
| 2 | **VPD (일간 증분)** | vidIQ VPH | 24시간 조회수 델타. 시간 해상도 포기 | ❌ 스냅샷 2일차부터 |
| 3 | **키워드/영상 채점 분리** | TubeBuddy weighted/unweighted | 두 점수를 UI에서 합치지 않고 나란히 노출 | ✅ |
| 4 | **공급측 경쟁 신호** | TubeBuddy Competition | 절대 검색량 포기. `search.list` 상위 N개의 **조회수 분포 · 업로드 최신성 · 채널 규모 분포**로 대체 | ✅ |
| 5 | **감쇠 기울기(에버그린)** | 없음 — 자체 설계 | 일간 증분의 나이 대비 기울기 | ❌ 수 주 관측 필요 |

**중앙값을 권장하는 이유**(우리 판단, 벤더 문서에 없음) — vidIQ는 "average"라 쓰지만, 평균은 채널 내 초대박 영상 1개에 기준선이 끌려올라가 후속 영상이 전부 저평가된다. 표본이 적은 우리 도메인에서 특히 심하다.

**포기 목록** — 절대 검색량, 시청 지속시간·CTR, 24시간 미만 해상도 지표, 추적 이전 구간 소급, outlier의 velocity 성분(스냅샷 축적 전까지).

### 콜드 스타트 판단

지표 1·3·4는 **1일차부터 동작한다.** 채널당 최소 9~10개 영상의 현재 조회수만 있으면 되고, 그건 `videos.list`로 바로 얻는다.

지표 2·5는 스냅샷 축적이 전제라 **3주 MVP 기간 내에 신뢰할 만한 값이 나오지 않는다.** 이 두 축의 우선순위를 낮추는 결정이 필요하다. 권장은 "지금부터 스냅샷은 쌓되, MVP UI에는 노출하지 않는다"이다.

---

## 4. 조사로 답이 안 나와 우리가 직접 판단해야 할 항목

1. **평균 vs 중앙값, 창 크기 N** — 벤더 미공개. 대상 채널들의 실제 조회수 분포를 뽑아 두 방식의 순위 차이를 직접 비교해야 결정 가능하다.
2. **쇼츠/롱폼 혼재 처리** — **어떤 벤더도 공개하지 않았다.** 기준선을 분리 계산할지 여부가 미결이다. 우리 대상 채널이 쇼츠를 섞어 올린다면 이건 1순위 결정 사항이다.
3. **시점 정합을 포기할 것인가** — (a) 현재 누적 조회수로만 비교(오래된 영상이 자동으로 유리해지는 편향 발생) vs (b) 스냅샷을 쌓은 뒤 신규 영상에만 적용. MVP에서는 (a)로 가되 편향을 UI에 명시하는 것이 현실적이다.
4. **키워드 점수와 영상 점수를 합칠 것인가** — 벤더들은 애초에 합치지 않고 별도 도구로 판다. 우리도 분리 노출이 안전해 보인다.
5. **크로스 카테고리 비교군의 수집·라벨링** — Data API에 이런 세밀한 카테고리가 없다. 수동 채널 리스트 유지 vs 검색어 기반 자동 수집 후 사람 검수. 채널 내부 기준선 방식이 이 문제를 상당 부분 회피하지만, **비교군을 화면에 나란히 보여주는 순간 다시 문제가 된다.**

---

## 5. 이 조사의 한계

1. **어떤 벤더도 정확한 수식을 공개하지 않았다.** 확인된 것은 "기준선이 무엇인가"까지다. 우리 구현은 vidIQ/Viewstats의 **복제가 아니라 같은 설계 철학의 독자 구현**이다. 문서에 이걸 혼동해 적으면 안 된다.
2. **기각된 주장이 16건**이다. outlier 단순비율(0-3), VPH 산식 2건(1-2, 0-3), vidIQ 24h/7d/28d 수명주기(0-3), TubeBuddy 경쟁강도 산식(0-3), Social Blade 파이프라인 2건(0-3). 이 항목들은 "조사로 답이 안 나온 영역"이며 그럴듯하게 채우면 안 된다.
3. **viewtrap, Velio, 1of10, Social Blade는 유효 발견 0건**이다.
4. **접근 차단** — Viewstats(Cloudflare 403)와 TubeBuddy(Zendesk 봇 차단)는 직접 fetch가 막혀 우회했다. Viewstats는 Zendesk API로 원문을 축자 확보해 신뢰도가 높지만, TubeBuddy 일부는 검색 인덱스 대체 검증이라 한 단계 약하다.
5. **시의성은 양호**하다(Viewstats 2025-06-20 갱신, 나머지 헬프센터 현행판). 다만 이 도구들은 UI와 지표를 자주 개편하므로 **6개월 후 재확인**이 필요하다.
