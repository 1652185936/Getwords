/** 生词条目（原型用内存模型；字段对齐最终版数据库设计） */
export interface WordItem {
  text: string;        // 条目主体（单词/短语/习语/句子）
  lemma: string;       // 去重键
  type: string;        // word / phrase / idiom / slang / sentence
  phonetic: string;    // 音标（仅单词，其余空串）
  pos: string;         // 词性（仅单词）
  cefr: string;        // 难度 A1/A2/B1/B2/C1/C2
  defZh: string;       // 中文释义
  example: string;     // 例句
  exampleZh: string;   // 例句译文
  context: string;     // 加入时所在原句(语境)
  sourceTitle: string; // 来源视频标题
  sourceTime: string;  // 来源时间戳
  dateAdded: string;   // 收录日期 MM-DD
  tags: string[];      // 标签
  status: number;      // 0 新词 / 1 学习中 / 2 已掌握
  due: boolean;        // 今日是否到期
  starred: boolean;    // 收藏
}

/** 通用色样（文字色 + 浅底色） */
export interface Chip {
  label: string;
  color: string;
  bg: string;
}

/** 筛选项配置 */
export interface FilterOption {
  label: string;
  value: string;
}

/** 状态色样 */
export function statusStyle(status: number): Chip {
  if (status === 2) {
    return { label: '已掌握', color: '#34C759', bg: '#E7F8EC' };
  }
  if (status === 1) {
    return { label: '学习中', color: '#FF9500', bg: '#FFF4E5' };
  }
  return { label: '新词', color: '#1A73E8', bg: '#E8F0FE' };
}

/** 单词「全解」附加信息（mock；后续由真实数据/DeepSeek 填充） */
export interface RichDetail {
  defEn: string;     // 英文释义
  similar: string[]; // 形近词
  root: string;      // 词根词缀助记
  forms: string;     // 单词变形
}

/** 全解数据表（按 lemma 索引；只给部分词做了 mock） */
export const RICH_DETAIL: Record<string, RichDetail> = {
  'photographer': {
    defEn: 'a person who takes photographs, especially as a job',
    similar: ['photography', 'photograph', 'photographic', 'geographer'],
    root: 'photo（光）+ graph（写/记录）→ 用光记录的人 → 摄影师',
    forms: 'photograph 照片 · photography 摄影 · photographic 摄影的'
  },
  'exchange': {
    defEn: 'to give something and receive something else in return',
    similar: ['change', 'charge', 'arrange', 'exhale'],
    root: 'ex（出）+ change（改变）→ 互相交出改变 → 交换',
    forms: 'exchanged · exchanging · exchanges'
  },
  'appreciate': {
    defEn: 'to recognize the good qualities of something; to be grateful for',
    similar: ['appropriate', 'approach', 'apprentice', 'precise'],
    root: 'ap（加强）+ preci（价值=price）+ ate → 看到价值 → 欣赏/感激',
    forms: 'appreciated · appreciation 感激(n.)'
  },
  'syllable': {
    defEn: 'a unit of pronunciation having one vowel sound',
    similar: ['syllabus', 'stable', 'valuable', 'liable'],
    root: 'syl（一起）+ lab（发声）+ le → 一起发出的音 → 音节',
    forms: 'syllabic 音节的(adj.)'
  },
  'pronunciation': {
    defEn: 'the way in which a word is pronounced',
    similar: ['pronounce', 'announcement', 'denunciation'],
    root: 'pro（向前）+ nounce（说）→ 说出来的方式 → 发音',
    forms: 'pronounce 发音(v.)'
  }
};

/** 类型色样 */
export function typeStyle(type: string): Chip {
  if (type === 'phrase') {
    return { label: '短语', color: '#00A0A0', bg: '#E0F7F7' };
  }
  if (type === 'idiom') {
    return { label: '习语', color: '#AF52DE', bg: '#F3E8FB' };
  }
  if (type === 'slang') {
    return { label: '俚语', color: '#FF6B00', bg: '#FFEFE0' };
  }
  if (type === 'sentence') {
    return { label: '句子', color: '#8E8E93', bg: '#EFEFF0' };
  }
  return { label: '单词', color: '#1A73E8', bg: '#E8F0FE' };
}

/** 难度色样（A 绿 / B 橙 / C 红紫） */
export function cefrStyle(cefr: string): Chip {
  if (cefr.startsWith('A')) {
    return { label: cefr, color: '#1E9E5A', bg: '#E7F8EC' };
  }
  if (cefr.startsWith('B')) {
    return { label: cefr, color: '#C77700', bg: '#FFF4E5' };
  }
  return { label: cefr, color: '#C0392B', bg: '#FDECEA' };
}

/** 类型筛选项 */
export const TYPE_FILTERS: FilterOption[] = [
  { label: '全部', value: '' },
  { label: '单词', value: 'word' },
  { label: '短语', value: 'phrase' },
  { label: '习语', value: 'idiom' },
  { label: '俚语', value: 'slang' },
  { label: '句子', value: 'sentence' }
];

/** 难度筛选项 */
export const CEFR_FILTERS: FilterOption[] = [
  { label: '全部', value: '' },
  { label: 'A1', value: 'A1' },
  { label: 'A2', value: 'A2' },
  { label: 'B1', value: 'B1' },
  { label: 'B2', value: 'B2' },
  { label: 'C1', value: 'C1' },
  { label: 'C2', value: 'C2' }
];

/** 原型用的丰富假数据（含单词/短语/习语/俚语/句子，覆盖各难度） */
export const MOCK_WORDS: WordItem[] = [
  { text: 'photographer', lemma: 'photographer', type: 'word', phonetic: '/fəˈtɑːɡrəfər/', pos: 'n.', cefr: 'B1', defZh: '摄影师', example: 'He is a famous photographer.', exampleZh: '他是个著名的摄影师。', context: 'Richard Stewart is a photographer.', sourceTitle: '走遍美国', sourceTime: '01:17', dateAdded: '06-18', tags: ['职业'], status: 0, due: true, starred: true },
  { text: 'exchange', lemma: 'exchange', type: 'word', phonetic: '/ɪksˈtʃeɪndʒ/', pos: 'n./v.', cefr: 'B1', defZh: '交换；交流', example: 'We exchanged numbers.', exampleZh: '我们交换了电话。', context: "I'm an exchange student.", sourceTitle: '走遍美国', sourceTime: '01:30', dateAdded: '06-18', tags: ['校园'], status: 0, due: true, starred: false },
  { text: 'syllable', lemma: 'syllable', type: 'word', phonetic: '/ˈsɪləbl/', pos: 'n.', cefr: 'C1', defZh: '音节', example: 'Cat has one syllable.', exampleZh: 'cat 有一个音节。', context: 'Do you know what a syllable is?', sourceTitle: '发音课', sourceTime: '00:47', dateAdded: '06-17', tags: ['语言学'], status: 0, due: true, starred: false },
  { text: 'pronunciation', lemma: 'pronunciation', type: 'word', phonetic: '/prəˌnʌnsiˈeɪʃn/', pos: 'n.', cefr: 'B2', defZh: '发音', example: 'Your pronunciation is great.', exampleZh: '你的发音很棒。', context: 'Learning English pronunciation can be challenging.', sourceTitle: '发音课', sourceTime: '00:00', dateAdded: '06-17', tags: ['语言学'], status: 1, due: true, starred: false },
  { text: 'emphasis', lemma: 'emphasis', type: 'word', phonetic: '/ˈemfəsɪs/', pos: 'n.', cefr: 'C1', defZh: '强调；重点', example: 'Put emphasis on the first syllable.', exampleZh: '重音放在第一个音节。', context: 'Word stress refers to the emphasis given to a syllable.', sourceTitle: '发音课', sourceTime: '00:39', dateAdded: '06-17', tags: ['语言学'], status: 1, due: false, starred: false },
  { text: 'album', lemma: 'album', type: 'word', phonetic: '/ˈælbəm/', pos: 'n.', cefr: 'A2', defZh: '相册；专辑', example: 'I made a photo album.', exampleZh: '我做了一本相册。', context: "It's an album of pictures.", sourceTitle: '走遍美国', sourceTime: '01:46', dateAdded: '06-16', tags: [], status: 1, due: true, starred: false },
  { text: 'ferry', lemma: 'ferry', type: 'word', phonetic: '/ˈferi/', pos: 'n.', cefr: 'B1', defZh: '渡轮', example: 'We took the ferry.', exampleZh: '我们坐了渡轮。', context: 'on the Staten Island Ferry.', sourceTitle: '走遍美国', sourceTime: '01:21', dateAdded: '06-16', tags: ['交通'], status: 1, due: false, starred: false },
  { text: 'appreciate', lemma: 'appreciate', type: 'word', phonetic: '/əˈpriːʃieɪt/', pos: 'v.', cefr: 'B2', defZh: '感激；欣赏', example: 'I really appreciate it.', exampleZh: '我真的很感激。', context: 'I appreciate your help.', sourceTitle: '走遍美国', sourceTime: '02:55', dateAdded: '06-16', tags: ['社交'], status: 1, due: true, starred: true },
  { text: 'terrific', lemma: 'terrific', type: 'word', phonetic: '/təˈrɪfɪk/', pos: 'adj.', cefr: 'C1', defZh: '极好的', example: 'You did a terrific job.', exampleZh: '你干得太棒了。', context: 'Terrific. Now give Mommy a kiss.', sourceTitle: '走遍美国', sourceTime: '03:10', dateAdded: '06-15', tags: [], status: 2, due: false, starred: false },
  { text: 'wonderful', lemma: 'wonderful', type: 'word', phonetic: '/ˈwʌndərfəl/', pos: 'adj.', cefr: 'A2', defZh: '精彩的；极好的', example: 'We had a wonderful time.', exampleZh: '我们玩得很开心。', context: 'Wonderful. Let me take your picture.', sourceTitle: '走遍美国', sourceTime: '03:25', dateAdded: '06-15', tags: [], status: 2, due: false, starred: true },
  { text: 'take pictures of', lemma: 'take pictures of', type: 'phrase', phonetic: '', pos: '', cefr: 'A2', defZh: '给…拍照', example: 'He takes pictures of the city.', exampleZh: '他给城市拍照。', context: 'He takes pictures of New York City.', sourceTitle: '走遍美国', sourceTime: '01:21', dateAdded: '06-18', tags: ['搭配'], status: 0, due: true, starred: false },
  { text: 'look for', lemma: 'look for', type: 'phrase', phonetic: '', pos: '', cefr: 'A2', defZh: '寻找；期待', example: "We'll be looking for your book.", exampleZh: '我们会期待你的书。', context: 'We will be looking for your book.', sourceTitle: '走遍美国', sourceTime: '03:30', dateAdded: '06-16', tags: ['搭配'], status: 1, due: false, starred: false },
  { text: 'a piece of cake', lemma: 'a piece of cake', type: 'idiom', phonetic: '', pos: '', cefr: 'B2', defZh: '小菜一碟；非常容易', example: 'The exam was a piece of cake.', exampleZh: '那考试小菜一碟。', context: "Don't worry, it's a piece of cake.", sourceTitle: '日常口语', sourceTime: '—', dateAdded: '06-18', tags: ['习语'], status: 0, due: true, starred: true },
  { text: 'break the ice', lemma: 'break the ice', type: 'idiom', phonetic: '', pos: '', cefr: 'C1', defZh: '打破僵局；活跃气氛', example: 'He told a joke to break the ice.', exampleZh: '他讲了个笑话活跃气氛。', context: 'A good question can break the ice.', sourceTitle: '日常口语', sourceTime: '—', dateAdded: '06-15', tags: ['习语'], status: 1, due: false, starred: false },
  { text: 'hang in there', lemma: 'hang in there', type: 'idiom', phonetic: '', pos: '', cefr: 'B2', defZh: '坚持住；别放弃', example: 'Hang in there, you can do it!', exampleZh: '坚持住，你能行！', context: 'It is hard, but hang in there.', sourceTitle: '日常口语', sourceTime: '—', dateAdded: '06-14', tags: ['习语'], status: 2, due: false, starred: false },
  { text: 'hang out', lemma: 'hang out', type: 'slang', phonetic: '', pos: '', cefr: 'B1', defZh: '（俚）一起玩；闲逛', example: 'Want to hang out this weekend?', exampleZh: '周末一起玩吗？', context: "Let's hang out sometime.", sourceTitle: '日常口语', sourceTime: '—', dateAdded: '06-17', tags: ['俚语', '口语'], status: 0, due: true, starred: false },
  { text: 'awesome', lemma: 'awesome', type: 'slang', phonetic: '/ˈɔːsəm/', pos: 'adj.', cefr: 'B1', defZh: '（俚）超棒的', example: 'That movie was awesome!', exampleZh: '那电影超棒！', context: 'This is awesome!', sourceTitle: '日常口语', sourceTime: '—', dateAdded: '06-16', tags: ['俚语', '口语'], status: 1, due: false, starred: false },
  { text: 'I appreciate your help.', lemma: 'i appreciate your help', type: 'sentence', phonetic: '', pos: '', cefr: 'B1', defZh: '感谢你的帮助。', example: '', exampleZh: '', context: 'Thank you. I appreciate your help.', sourceTitle: '走遍美国', sourceTime: '02:55', dateAdded: '06-18', tags: ['礼貌用语'], status: 0, due: true, starred: false },
  { text: "What's it for?", lemma: "what's it for", type: 'sentence', phonetic: '', pos: '', cefr: 'A2', defZh: '这是做什么用的？', example: '', exampleZh: '', context: "It's for a book. What's it for?", sourceTitle: '走遍美国', sourceTime: '02:38', dateAdded: '06-17', tags: ['日常对话'], status: 1, due: false, starred: false },
  { text: 'May I take a picture of you?', lemma: 'may i take a picture of you', type: 'sentence', phonetic: '', pos: '', cefr: 'B1', defZh: '我可以给你拍张照吗？', example: '', exampleZh: '', context: 'May I take a picture of you and your little boy?', sourceTitle: '走遍美国', sourceTime: '02:38', dateAdded: '06-15', tags: ['日常对话'], status: 2, due: false, starred: false }
];
