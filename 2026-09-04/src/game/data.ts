import type { CustomerKind, ProductDefinition, StoreEvent } from './types'

export const products: ProductDefinition[] = [
  { id: 'onigiri', name: 'おにぎり', price: 168, cost: 82, unlockTier: 1, color: '#f6f0d1', shelf: { x: 7, y: 4 } },
  { id: 'drink', name: '飲みもの', price: 148, cost: 61, unlockTier: 1, color: '#69b7d1', shelf: { x: 12, y: 4 } },
  { id: 'bread', name: 'パン', price: 178, cost: 76, unlockTier: 1, color: '#d9a055', shelf: { x: 7, y: 8 } },
  { id: 'snack', name: 'おかし', price: 138, cost: 53, unlockTier: 1, color: '#ef7f72', shelf: { x: 12, y: 8 } },
  { id: 'bento', name: 'お弁当', price: 548, cost: 302, unlockTier: 2, color: '#88a85b', shelf: { x: 15, y: 4 } },
  { id: 'hot', name: 'ホットスナック', price: 228, cost: 103, unlockTier: 3, color: '#dc6b32', shelf: { x: 15, y: 8 } },
]

export const customerProfiles: Record<CustomerKind, { name: string; color: string; favorites: ProductDefinition['id'][] }> = {
  worker: { name: '会社員', color: '#315f93', favorites: ['bento', 'onigiri', 'drink'] },
  student: { name: '学生', color: '#d04f4f', favorites: ['hot', 'snack', 'drink'] },
  neighbor: { name: 'ご近所さん', color: '#b66c9d', favorites: ['bread', 'onigiri', 'drink'] },
  nightowl: { name: '深夜の人', color: '#64518e', favorites: ['snack', 'drink', 'hot'] },
  collector: { name: '新商品ハンター', color: '#cb8a24', favorites: ['snack', 'drink', 'bento'] },
}

export const events: StoreEvent[] = [
  { id: 'normal', name: '平常営業', detail: '今日もだいたい平和です。', demandMultiplier: 1 },
  { id: 'rain', name: '雨の一日', detail: '寄り道客が増え、温かい食べ物が人気。', demandMultiplier: 1.18, productBoost: 'hot' },
  { id: 'sports', name: '近所で運動会', detail: 'おにぎりを求める人々が接近中。', demandMultiplier: 1.38, productBoost: 'onigiri' },
  { id: 'buzz', name: 'おかしが話題', detail: '新商品ハンターが棚を見張っています。', demandMultiplier: 1.3, productBoost: 'snack' },
  { id: 'quiet', name: '妙に静かな日', detail: '店長は床を二度磨きました。', demandMultiplier: 0.72 },
  { id: 'festival', name: '商店街のお祭り', detail: '飲みものと軽食がよく売れます。', demandMultiplier: 1.52, productBoost: 'drink' },
]
