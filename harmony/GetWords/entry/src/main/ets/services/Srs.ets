/**
 * 间隔重复（Spaced Repetition）方法论 —— 借鉴 Anki 的 SM-2 遗忘曲线。
 *
 * 核心思想：人对一个词的记忆会随时间指数衰减（遗忘曲线）。在「快要忘」的时间点
 * 复习一次，记忆就被强化、衰减变慢，于是复习间隔可以越拉越长。
 *
 * 每张卡维护三个量：
 *   - ease   难度系数(EF)：这个词对你有多容易，越大下次间隔涨得越快（1.3~3.0）。
 *   - interval 当前间隔(天)：距下次复习多少天。0 表示「还没毕业」，10 分钟后再来。
 *   - reps   连续答对次数：用来决定毕业阶梯（1天 → 4天 → 按 ease 指数增长）。
 *
 * 我们把 3 档人话评分映射到 SM-2 的难度反馈（而不是 Anki 的四个术语按钮）：
 *   😵 忘了 → 清零重来，ease 下调，10 分钟后重现。
 *   🤔 模糊 → 算答对但偏难，ease 略降，间隔小步增长。
 *   😎 记得 → 答对，ease 略升，间隔按 ease 拉长。
 */

/** 一张卡的间隔重复状态 */
export interface SrsState {
  ease: number;     // 难度系数 EF（1.3 ~ 3.0）
  interval: number; // 当前间隔(天)，0 表示未毕业
  reps: number;     // 连续答对次数
  lapses: number;   // 遗忘次数
}

/** 评分：忘了 / 模糊 / 记得 */
export const GRADE_FORGOT: number = 0;
export const GRADE_VAGUE: number = 1;
export const GRADE_KNOWN: number = 2;

/**
 * 按评分推进一张卡的间隔重复状态（纯函数，方便测试/将来换 FSRS）。
 * @param s 当前状态
 * @param grade 评分（0 忘了 / 1 模糊 / 2 记得）
 * @returns 推进后的新状态
 */
export function applyGrade(s: SrsState, grade: number): SrsState {
  let ease: number = s.ease;         // 新难度系数
  let reps: number = s.reps;         // 新连对次数
  let lapses: number = s.lapses;     // 新遗忘次数
  let interval: number = s.interval; // 新间隔

  if (grade === GRADE_FORGOT) {
    reps = 0;
    lapses = s.lapses + 1;
    ease = Math.max(1.3, s.ease - 0.20);
    interval = 0; // 不到一天，约 10 分钟后重现
  } else {
    reps = s.reps + 1;
    if (grade === GRADE_VAGUE) {
      ease = Math.max(1.3, s.ease - 0.15);
      if (reps === 1) {
        interval = 1;
      } else if (reps === 2) {
        interval = 3;
      } else {
        interval = Math.round(s.interval * ease * 0.8); // 偏难，打八折增长
      }
    } else {
      ease = Math.min(3.0, s.ease + 0.10);
      if (reps === 1) {
        interval = 3;
      } else if (reps === 2) {
        interval = 7;
      } else {
        interval = Math.round(s.interval * ease); // 按 ease 指数增长
      }
    }
    if (interval < 1) {
      interval = 1;
    }
  }
  return { ease: ease, interval: interval, reps: reps, lapses: lapses };
}

/**
 * 原型用：按掌握状态给一个合理的初始 SRS 状态（最终版从数据库读真实值）。
 * @param status 0 新词 / 1 学习中 / 2 已掌握
 * @returns 初始状态
 */
export function initialState(status: number): SrsState {
  if (status === 2) {
    return { ease: 2.6, interval: 15, reps: 4, lapses: 0 };
  }
  if (status === 1) {
    return { ease: 2.5, interval: 3, reps: 2, lapses: 0 };
  }
  return { ease: 2.5, interval: 0, reps: 0, lapses: 0 };
}

/**
 * 把间隔渲染成人话（10分钟 / N天 / N个月 / N年）。
 * @param interval 间隔天数
 * @returns 文案
 */
export function intervalLabel(interval: number): string {
  if (interval <= 0) {
    return '10分钟';
  }
  if (interval === 1) {
    return '1天';
  }
  if (interval < 30) {
    return `${interval}天`;
  }
  if (interval < 365) {
    return `${Math.round(interval / 30)}个月`;
  }
  return `${Math.round(interval / 365)}年`;
}

/**
 * 预览：若选某评分，下次将在多久后复习（显示在按钮上，让方法论可见）。
 * @param s 当前状态
 * @param grade 评分
 * @returns 文案
 */
export function previewLabel(s: SrsState, grade: number): string {
  return intervalLabel(applyGrade(s, grade).interval);
}
