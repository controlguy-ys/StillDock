# AI 시대의 프로그래밍 — 20분 샘플 강의 덱 생성기

슬라이드 내용, 디자인 값, 렌더링 코드를 분리한 데이터 기반 PPTX 생성기입니다.

```bash
npm install
npm run build                       # → out/AI_Era_Programming_Sample_Lecture.pptx
node src/build.js --content <json> --theme <json> --out <pptx>   # 다른 강의/테마로 빌드
```

| 경로 | 역할 |
| --- | --- |
| `content/lecture.json` | 슬라이드 문구, 섹션, 슬라이드별 시간(`minutes`), 발표자 노트, 블록 구성 |
| `config/theme.json` | 색상(테마 슬롯·톤), 폰트, 그리드, 글자 크기, 블록별 치수 |
| `config/build.json` | 기본 입력/출력 경로, 아이콘 라이브러리 |
| `src/blocks/` | 블록 렌더러 (`agenda`, `steps`, `code`, `staircase`, `shiftTable` 등) — `index.js`에 등록 |
| `src/lib/` | 테마·그리드·텍스트 측정·타이밍·레이아웃·테마 패치 모듈 |

- 각 블록은 `region: { cols: [시작, 폭], rows: [행, 폭, 총행] }`으로 12칼럼 그리드에 배치됩니다.
- 문구의 `**강조**`는 테마 강조색 굵은 글씨가 됩니다.
- 아젠다 시간대와 노트의 타이밍은 슬라이드별 `minutes`에서 계산되며, 합계가 `meta.totalMinutes`와 다르면 빌드가 실패합니다.
- 빌드는 넘칠 가능성이 있는 텍스트를 경고로 출력합니다(종료 코드 2).
