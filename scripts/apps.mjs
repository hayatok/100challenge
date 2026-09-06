import { readFile } from 'node:fs/promises'

export const appIdPattern = /^\d{4}-\d{2}-\d{2}(?:-(?:[2-9]|[1-9]\d+))?$/

export function selectApps(apps, args) {
  if (args.length === 0) return apps
  if (args.length !== 2 || args[0] !== '--apps-json') throw new Error('Expected --apps-json followed by an array of app IDs')
  const ids = JSON.parse(args[1])
  if (!Array.isArray(ids) || ids.some(id => typeof id !== 'string' || !apps.some(app => app.id === id))) {
    throw new Error('Selected apps must be registered app IDs')
  }
  if (new Set(ids).size !== ids.length) throw new Error('Duplicate selected app ID')
  return apps.filter(app => ids.includes(app.id))
}

export async function loadApps(fileUrl) {
  const apps = JSON.parse(await readFile(fileUrl, 'utf8'))

  if (!Array.isArray(apps)) {
    throw new Error('apps.json must contain an array')
  }

  const ids = new Set()

  for (const app of apps) {
    if (!appIdPattern.test(app.id)) {
      throw new Error(`Invalid app id: ${app.id}`)
    }
    if (ids.has(app.id)) {
      throw new Error(`Duplicate app id: ${app.id}`)
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(app.date)) {
      throw new Error(`Invalid app date: ${app.date}`)
    }
    if (!Number.isInteger(app.sequence) || app.sequence < 1) {
      throw new Error(`Invalid sequence for ${app.id}`)
    }
    if (app.id !== `${app.date}${app.sequence === 1 ? '' : `-${app.sequence}`}`) {
      throw new Error(`App id and sequence do not match: ${app.id}`)
    }
    ids.add(app.id)
  }

  return apps
}
