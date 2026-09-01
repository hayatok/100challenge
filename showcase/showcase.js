const list = document.querySelector('#app-list')
const template = document.querySelector('#app-card-template')
const appCount = document.querySelector('#app-count')
const progressBar = document.querySelector('#progress-bar')
const progressCopy = document.querySelector('#progress-copy')

function formatDate(date) {
  const [year, month, day] = date.split('-')
  return `${year}.${month}.${day}`
}

function renderStatus(mark, title, message) {
  list.replaceChildren()
  const panel = document.createElement('div')
  panel.className = 'status-panel'
  panel.innerHTML = `<span class="status-mark" aria-hidden="true"></span><div><strong></strong><p></p></div>`
  panel.querySelector('.status-mark').textContent = mark
  panel.querySelector('strong').textContent = title
  panel.querySelector('p').textContent = message
  list.append(panel)
  list.removeAttribute('aria-busy')
}

function renderApps(apps) {
  appCount.textContent = String(apps.length).padStart(2, '0')
  progressBar.style.width = `${Math.min(apps.length, 100)}%`
  progressCopy.textContent = apps.length === 1 ? '最初の1歩を記録しました' : `${apps.length}個の実験を公開中`

  if (apps.length === 0) {
    renderStatus('0', '最初の作品を待っています', '日付フォルダを追加すると、ここに自動で並びます。')
    return
  }

  list.replaceChildren()
  const sortedApps = [...apps].sort((a, b) => b.date.localeCompare(a.date) || b.sequence - a.sequence)

  for (const app of sortedApps) {
    const card = template.content.firstElementChild.cloneNode(true)
    const href = `./${app.id}/`
    const image = card.querySelector('.app-image')

    card.style.setProperty('--card-accent', app.accent)
    card.querySelectorAll('a').forEach((link) => { link.href = href })
    card.querySelector('time').dateTime = app.date
    card.querySelector('time').textContent = formatDate(app.date)
    card.querySelector('.app-sequence').textContent = app.sequence === 1 ? '1本目' : `${app.sequence}本目`
    card.querySelector('h3 a').textContent = app.name
    card.querySelector('.app-description').textContent = app.description
    card.querySelector('.app-category').textContent = app.category
    image.src = `${href}${app.thumbnail}`
    image.alt = `${app.name}のプレビュー`
    list.append(card)
  }

  list.removeAttribute('aria-busy')
}

try {
  const response = await fetch('./apps.json')
  if (!response.ok) throw new Error(`HTTP ${response.status}`)
  renderApps(await response.json())
} catch (error) {
  console.error(error)
  appCount.textContent = '--'
  progressCopy.textContent = '一覧を読み込めませんでした'
  renderStatus('!', '作品一覧を読み込めませんでした', 'ページを再読み込みしてください。')
}
