// SPARTA Content Lab 디자인 토큰 → Tailwind 매핑.
// 값의 단일 원천은 DESIGN.md §10 (single source of truth). 여기 값을 임의로 바꾸지 말고 DESIGN.md에서만 고친다.
// 원시 Tailwind 팔레트 색(blue-600, indigo-500, green-600 등) 직접 사용 금지 — 토큰만 쓴다 (CLAUDE.md / DESIGN.md §11).

module.exports = {
  content: [
    './public/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html,slim}'
  ],
  theme: {
    extend: {
      colors: {
        primary: { 50:'#EEF2FE',100:'#DCE4FD',500:'#2E5BE6',600:'#1145DD',700:'#0E37B0' },
        success: { 50:'#E7F6EC',100:'#C6EBD1',600:'#159C49',700:'#0F7A38' },
        warning: { 50:'#FEF3E4',500:'#F59E0B',600:'#B45309' },
        // 성과 배수 밴드
        mult: { good:'#15803D', strong:'#0F7A38', breakout:'#159C49' },
        // 뱃지
        badge: { neutralBg:'#F2F4F7', neutralFg:'#4B5563',
                 cautionBg:'#FEF1E3', cautionFg:'#F56B04',
                 dangerBg:'#FEEEEF',  dangerFg:'#C31334' },
        app:     '#FBFCFD',
        surface: { DEFAULT:'#FFFFFF', sunken:'#F7F8FA' },
        border:  { DEFAULT:'#E5E7EB', subtle:'#EEF1F5' },
        ink:     { strong:'#111827', body:'#374151', muted:'#6B7280', subtle:'#9CA3AF' },
      },
      fontFamily: {
        sans: ['Pretendard','Noto Sans KR','Noto Sans JP','system-ui',
               '-apple-system','Hiragino Kaku Gothic ProN','Yu Gothic','Meiryo','sans-serif'],
      },
      fontSize: {
        score:   ['40px',{ lineHeight:'1.1',  fontWeight:'800' }],
        h1:      ['28px',{ lineHeight:'1.3',  fontWeight:'700' }],
        h2:      ['20px',{ lineHeight:'1.35', fontWeight:'700' }],
        h3:      ['18px',{ lineHeight:'1.4',  fontWeight:'600' }],
        nav:     ['15px',{ lineHeight:'1.4',  fontWeight:'500' }],
        body:    ['14px',{ lineHeight:'1.5' }],
        caption: ['13px',{ lineHeight:'1.45' }],
        label:   ['12px',{ lineHeight:'1.4',  fontWeight:'500' }],
      },
      borderRadius: { card:'12px', control:'8px', chip:'6px' },
      boxShadow: {
        card:      '0 1px 2px rgba(16,24,40,0.04), 0 1px 3px rgba(16,24,40,0.06)',
        cardHover: '0 2px 4px rgba(16,24,40,0.06), 0 4px 8px rgba(16,24,40,0.08)',
        dropdown:  '0 4px 12px rgba(16,24,40,0.10)',
      },
    },
  },
  plugins: [
    require('@tailwindcss/forms'),
    require('@tailwindcss/typography'),
    require('@tailwindcss/container-queries'),
  ]
}
