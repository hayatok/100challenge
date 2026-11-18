const byId = id => document.getElementById(id);
const racer = byId('racer');
const pose = byId('pose');
const height = byId('height');
const revision = byId('revision');
const canvases = [byId('old'), byId('now')];
const directionButtons = Array.from(document.querySelectorAll('[data-frame]'));
const stage = byId('stage');
const viewNames = [
  '正面', '右斜め前', '右斜め前', '右斜め前',
  '右横', '右斜め後ろ', '右斜め後ろ', '右斜め後ろ',
  '背面', '左斜め後ろ', '左斜め後ろ', '左斜め後ろ',
  '左横', '左斜め前', '左斜め前', '左斜め前',
];
let frame = 12;
let sheets = [];
let request = 0;

function drawFrame(value) {
  frame = (value % 16 + 16) % 16;
  const angle = viewNames[frame] + '　' + (frame * 22.5) + '°';
  byId('angle').textContent = angle;
  for (const button of directionButtons) {
    button.setAttribute('aria-pressed', String(Number(button.dataset.frame) === frame));
  }
  const name = racer.selectedOptions[0].textContent.trim();
  sheets.forEach((image, i) => {
    const target = canvases[i];
    const width = image.naturalWidth / 4;
    const tall = image.naturalHeight / 4;
    if (target.width !== width || target.height !== tall) {
      target.width = width;
      target.height = tall;
    }
    const ctx = target.getContext('2d');
    ctx.clearRect(0, 0, width, tall);
    ctx.drawImage(image, frame % 4 * width, Math.floor(frame / 4) * tall, width, tall, 0, 0, width, tall);
    const version = i === 0 ? revision.selectedOptions[0].textContent : 'v0.3.1';
    target.setAttribute('aria-label', [name, version, pose.selectedOptions[0].textContent,
      height.selectedOptions[0].textContent, angle].join('、'));
  });
}

function loadSheet(version) {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = reject;
    image.src = 'frames/' + version + '/' + [racer.value, pose.value, height.value].join('-') + '.webp';
  });
}

function showMessage(text, retry = false) {
  byId('message-text').textContent = text;
  byId('message').hidden = !text;
  byId('retry').hidden = !retry;
}

async function loadComparison() {
  const ticket = ++request;
  const isNagi = racer.value === '01';
  const older = revision.querySelector('[value="v02"]');
  older.disabled = !isNagi;
  if (!isNagi) revision.value = 'v03';
  const reference = byId('reference');
  const art = isNagi ? 'nagi-reference.webp' : 'cast-reference.webp';
  if (reference.getAttribute('src') !== art) reference.src = art;
  reference.alt = isNagi ? 'ナギの原画。正面、本人の左横、背面。' : '6人の正面設定画。左からナギ、スズ、リッカ、アン、ネネ、ミオ。';
  byId('ref-heading').textContent = isNagi ? 'ナギの三面図' : '6人の正面設定画';
  sheets = [];
  stage.setAttribute('aria-busy', 'true');
  for (const canvas of canvases) canvas.hidden = true;
  showMessage('モデルを読み込み中…');
  try {
    const loaded = await Promise.all([loadSheet(revision.value), loadSheet('current')]);
    if (ticket !== request) return;
    sheets = loaded;
    for (const canvas of canvases) canvas.hidden = false;
    drawFrame(frame);
    showMessage('');
  } catch {
    if (ticket === request) showMessage('モデル画像を読み込めませんでした。', true);
  } finally {
    if (ticket === request) stage.setAttribute('aria-busy', 'false');
  }
}

for (const field of [racer, pose, height, revision]) field.addEventListener('change', loadComparison);
byId('retry').addEventListener('click', loadComparison);
byId('previous').addEventListener('click', () => drawFrame(frame - 1));
byId('next').addEventListener('click', () => drawFrame(frame + 1));
for (const button of directionButtons) {
  button.addEventListener('click', () => drawFrame(Number(button.dataset.frame)));
}
document.addEventListener('keydown', event => {
  if (event.target instanceof HTMLSelectElement || event.altKey || event.ctrlKey || event.metaKey) return;
  if (event.key === 'ArrowLeft' || event.key === 'ArrowRight') {
    event.preventDefault();
    drawFrame(frame + (event.key === 'ArrowRight' ? 1 : -1));
  }
});

let drag;
stage.addEventListener('pointerdown', event => {
  if (!event.isPrimary || event.button !== 0 || !event.target.closest('.photo')) return;
  drag = { x: event.clientX, frame, id: event.pointerId };
  stage.setPointerCapture(event.pointerId);
});
stage.addEventListener('pointermove', event => {
  if (drag?.id !== event.pointerId) return;
  drawFrame(drag.frame + Math.trunc((event.clientX - drag.x) / 22));
});
stage.addEventListener('lostpointercapture', () => { drag = undefined; });

drawFrame(frame);
loadComparison();
