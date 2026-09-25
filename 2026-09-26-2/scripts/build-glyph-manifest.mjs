import * as fontkit from 'fontkit'
import { writeFile } from 'node:fs/promises'
const files=['public/fonts/SpaceGrotesk.ttf','public/fonts/noto-sans-jp-japanese-700-normal.woff2']
const set=new Set(files.flatMap(file=>fontkit.openSync(file).characterSet))
await writeFile('src/engine/glyphs.json',JSON.stringify([...set].sort((a,b)=>a-b)))
