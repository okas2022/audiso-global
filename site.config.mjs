/** @typedef {{ id: string, label: Record<string, string>, href: string }} NavItem */

export const SITE = {
  name: 'Audiso · AudiMall',
  domain: 'audimall.vercel.app',
  baseUrl: 'https://audimall.vercel.app',
  koStore: 'https://peacetop.store',
  companyUrl: 'https://audiso.co.kr',
};

/** @type {Record<string, { code: string, label: string, dir: string, live: boolean }>} */
export const LOCALES = {
  en: { code: 'en', label: 'EN', dir: 'ltr', live: true },
  zh: { code: 'zh', label: '中文', dir: 'ltr', live: true },
  ja: { code: 'ja', label: '日本語', dir: 'ltr', live: true },
};

/** @type {NavItem[]} */
export const NAV = [
  { id: 'home', label: { en: 'Home', zh: '首页', ja: 'ホーム' }, href: '' },
  { id: 'about', label: { en: 'About', zh: '关于我们', ja: '会社概要' }, href: 'about' },
  { id: 'partners', label: { en: 'Partners', zh: '合作', ja: 'パートナー' }, href: 'partners' },
  { id: 'withhear', label: { en: 'WithHear', zh: 'WithHear', ja: 'WithHear' }, href: 'withhear' },
  { id: 'peacetop', label: { en: 'Peacetop', zh: 'Peacetop', ja: 'Peacetop' }, href: 'peacetop' },
  { id: 'modoo', label: { en: 'Modoo Hearing', zh: 'Modoo Hearing', ja: 'Modoo Hearing' }, href: 'modoo' },
  { id: 'mindtone', label: { en: 'MindTone T', zh: 'MindTone T', ja: 'MindTone T' }, href: 'mindtone' },
  { id: 'contact', label: { en: 'Contact', zh: '联系', ja: 'お問い合わせ' }, href: 'contact' },
];

/** @type {Record<string, Record<string, { title: string, description: string }>>} */
export const PAGE_META = {
  en: {
    index: {
      title: 'Audiso · Smart Ear Care for Everyday Life',
      description: 'Audiso AudiMall — AI hearing tests, ear-care nutrition, free hearing apps, and digital rehab. Total ear-care from screening to wellness.',
    },
    about: {
      title: 'About Audiso — Mission, Vision & Ear-Care Ecosystem',
      description: 'Audiso is a KOLAS-accredited AI hearing healthcare company connecting screening, understanding, nutrition, and digital rehabilitation.',
    },
    partners: {
      title: 'Audiso Partnerships — Exclusive Distribution & B2B',
      description: 'US/EU distribution and co-development for WithHear, Modoo Hearing, Peacetop, and MindTone — clinically grounded K-Audiology ecosystem.',
    },
    withhear: {
      title: 'WithHear 2.0 — AI Hearing Test Kiosk',
      description: '3-minute self-service AI hearing tests for clinics, retail, and workplaces. Built on nationally certified Korean hearing data.',
    },
    peacetop: {
      title: 'Peacetop Triple Care — Ear-Care Nutrition',
      description: 'Daily ear-care nutrition supporting ear, vascular, and nerve balance — the wellness step after hearing screening.',
    },
    modoo: {
      title: 'Modoo Hearing — Free Hearing Test App & Web',
      description: 'Free hearing tests on smartphone and web. Understand results and share with family — your everyday hearing companion.',
    },
    mindtone: {
      title: 'MindTone T Care — Digital Tinnitus & Hearing Rehab',
      description: 'Personalized training app and sensory therapy device for tinnitus, hearing loss, and dizziness — 10 minutes a day at home.',
    },
    contact: {
      title: 'Contact Audiso — Partnerships & Inquiries',
      description: 'Reach Audiso for WithHear deployment, partnerships, and product inquiries. Korean store available at peacetop.store.',
    },
    whitepaper: {
      title: 'Free Whitepaper — Korean Normative Hearing Data & ISO 7029',
      description: 'Download Audiso\'s technical brief on 1,089 Korean PTA reference standards, ISO 7029 comparison, and KOLAS-calibrated hearing science for global OEM and clinical partners.',
    },
    'vdr-ir-deck': {
      title: 'Audiso IR Deck — Interactive Virtual Data Room',
      description: 'Confidential 12-slide investor & partnership overview with clinical data moat, MindTone SaMD path, and global traction.',
    },
  },
  zh: {
    index: {
      title: 'Audiso · 提升日常生活的智能耳部护理',
      description: 'Audiso AudiMall — AI听力检测、耳部营养、免费听力应用与数字康复。从筛查到日常护理的完整耳部健康方案。',
    },
    about: {
      title: '关于 Audiso — 使命、愿景与耳部护理生态',
      description: 'Audiso 是 KOLAS 认证的 AI 听力医疗企业，连接筛查、理解、营养与数字康复。',
    },
    withhear: {
      title: 'WithHear 2.0 — AI 听力检测 kiosk',
      description: '3分钟自助 AI 听力检测，适用于诊所、零售与企业。基于韩国国家认证听力数据。',
    },
    peacetop: {
      title: 'Peacetop Triple Care — 耳部护理营养',
      description: '每日耳部、血管与神经平衡营养 — 听力筛查后的日常护理步骤。',
    },
    modoo: {
      title: 'Modoo Hearing — 免费听力检测 App 与 Web',
      description: '手机与网页免费听力检测。理解结果并与家人分享 — 您的日常听力伙伴。',
    },
    mindtone: {
      title: 'MindTone T Care — 数字耳鸣与听力康复',
      description: '个性化训练 App 与感官理疗设备，针对耳鸣、听力损失与眩晕 — 每天约10分钟居家护理。',
    },
    contact: {
      title: '联系 Audiso — 合作与咨询',
      description: 'WithHear 部署、企业合作与产品咨询。韩国商城：peacetop.store。',
    },
  },
  ja: {
    index: {
      title: 'Audiso · 日常を豊かにするスマート耳ケア',
      description: 'Audiso AudiMall — AI聴力検査、耳ケア栄養、無料聴力アプリ、デジタルリハビリ。検査からウェルネスまで。',
    },
    about: {
      title: 'Audiso について — ミッション・ビジョンと耳ケアエコシステム',
      description: 'KOLAS認証のAI聴力ヘルスケア企業。検査・理解・栄養・デジタルリハビリをつなぎます。',
    },
    withhear: {
      title: 'WithHear 2.0 — AI聴力検査キオスク',
      description: '3分セルフサービスAI聴力検査。クリニック・小売・職場向け。国家認証データ基盤。',
    },
    peacetop: {
      title: 'Peacetop Triple Care — 耳ケア栄養',
      description: '耳・血管・神経バランスを1日1パック。聴力検査後のウェルネスステップ。',
    },
    modoo: {
      title: 'Modoo Hearing — 無料聴力検査アプリ＆Web',
      description: 'スマホ・Webで無料聴力検査。結果を理解し家族と共有 — 日常の聴力パートナー。',
    },
    mindtone: {
      title: 'MindTone T Care — デジタル耳鳴り・聴力リハビリ',
      description: '耳鳴り・難聴・めまい向けパーソナライズアプリと感覚テラピーデバイス。自宅で1日10分。',
    },
    contact: {
      title: 'Audiso お問い合わせ — パートナーシップ・製品相談',
      description: 'WithHear導入、企業パートナーシップ、製品に関するお問い合わせ。韓国ストア：peacetop.store。',
    },
  },
};

export const CONTACT = {
  email: 'audiso@audiso.co.kr',
  koInquiry: 'https://peacetop.store/qna/form',
  modooWeb: 'https://moduhearingaids.vercel.app/',
  modooIos: 'https://apps.apple.com/kr/app/%EB%AA%A8%EB%91%90%EC%9D%98-%EB%B3%B4%EC%B2%AD%EA%B8%B0/id6476432937',
  modooAndroid: 'https://play.google.com/store/apps/details?id=com.flynnapps.hearingaid',
  mindtoneIos: 'https://apps.apple.com/kr/app/%EB%A7%88%EC%9D%B8%EB%93%9C%ED%86%A4-mindtone-%EC%82%AC%EC%9A%B4%EB%93%9C-%EC%9B%B0%EB%8B%88%EC%8A%A4/id6759947338',
  mindtoneAndroid: 'https://play.google.com/store/apps/details?id=kr.co.audiso.mindtone',
};

export const IMAGES = {
  hero: 'https://cdn.sixshop.io/sf-gateway/public/stores/audiso/website/피스탑-뷰티샷-(2)_1779264997980.png',
  withhear: 'https://cdn.sixshop.io/commerce/public/stores/audiso/products/%ED%82%A4%EC%98%A4%EC%8A%A4%ED%81%AC-%EC%A0%9C%ED%92%88%EC%83%B7_1781740631391.png',
  peacetop: 'https://cdn.sixshop.io/commerce/public/stores/audiso/products/Gemini_Generated_Image_irbu0tirbu0tirbu_1781226653373.png',
  modooApp: 'https://cdn.sixshop.io/sf-gateway/public/stores/audiso/website/modoo-app-promo_1782862780403.jpg',
  modooTest: 'https://cdn.sixshop.io/sf-gateway/public/stores/audiso/website/modoo-app-hearing-test_1782862780403.jpg',
  mindtoneHw: 'https://cdn.sixshop.io/sf-gateway/public/stores/audiso/website/mindtone-hw-front-full_1782863814058.jpg',
  mindtoneProduct: 'https://cdn.sixshop.io/commerce/public/stores/audiso/products/%EB%A7%88%EC%9D%B8%EB%93%9C%ED%86%A4_1782865940800.png',
  wcaBooth: 'https://postfiles.pstatic.net/MjAyNjA2MDRfMjgx/MDAxNzgwNTU5ODc1NTQ2.uAgMkS70zPj2AB7EdnLPrwH6pqpf2a7VuCthRClF7LAg.-ZBrsenT2fo9DkNIIC92rvLrnre_SnCtIvh6AJPMSQ0g.JPEG/IMG_5147.jpeg?type=w966',
  kolas: 'https://cdn.imweb.me/upload/S20231004156d9e93a64cf/3d8cd80012889.png',
  logo: 'http://blogpfthumb.phinf.naver.net/MjAyNTA4MjJfMjE0/MDAxNzU1ODM3NTUyMTUz.K0CNTmvF_aczqRHg2VtEqgNarEz7WEej3dRI67wGr6Yg.x6S2rY547oTDu995uE8-fYtZ95B2o91lu6ZhG5c5lJ0g.PNG/%EB%A1%9C%EA%B3%A0-01.png/%25EB%25A1%259C%25EA%25B3%25A0-01.png?type=m2',
};
