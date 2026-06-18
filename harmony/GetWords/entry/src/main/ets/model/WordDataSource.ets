import { WordItem } from './Word';

/**
 * 生词列表的懒加载数据源（配合 LazyForEach）。
 * 即便上万条，列表也只渲染可见项；这里用内存数组，最终版会换成数据库分页。
 */
export class WordDataSource implements IDataSource {
  private items: WordItem[] = [];                 // 当前（筛选后）数据
  private listeners: DataChangeListener[] = [];   // 监听器

  /**
   * 替换数据并通知列表刷新。
   * @param items 新数据
   */
  setItems(items: WordItem[]): void {
    this.items = items;
    for (const l of this.listeners) {
      l.onDataReloaded();
    }
  }

  /** 数据总数 */
  totalCount(): number {
    return this.items.length;
  }

  /**
   * 取指定下标的数据。
   * @param index 下标
   * @returns 该条目
   */
  getData(index: number): WordItem {
    return this.items[index];
  }

  /**
   * 注册监听器。
   * @param listener 监听器
   */
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  /**
   * 注销监听器。
   * @param listener 监听器
   */
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const i: number = this.listeners.indexOf(listener); // 监听器下标
    if (i >= 0) {
      this.listeners.splice(i, 1);
    }
  }
}
