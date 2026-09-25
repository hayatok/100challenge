import { makeRecipe } from '../domain/generate'
import { palettes, type Recipe } from '../domain/model'
export function heroRecipes():Recipe[]{
  const h1=makeRecipe({title:'余白の、\nその先。',subtitle:''},'square','weave',0,250925)
  h1.color={paletteId:'paper',...palettes.paper};h1.type={fontId:'noto-serif-jp-600',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h1.shape={composition:'sweep',density:'medium',tilt:0,seed:104}
  const h2=makeRecipe({title:'まだ、\n途中です。',subtitle:''},'square','fold',0,250926)
  h2.color={paletteId:'night',...palettes.night};h2.type={fontId:'noto-sans-jp-700',align:'center',size:'large',lineHeight:1.15,letterSpacing:0};h2.shape={composition:'fan',density:'low',tilt:0,seed:205}
  const h3=makeRecipe({title:'PLAY\nWITH TYPE',subtitle:''},'square','tile',0,250927)
  h3.color={paletteId:'blue',...palettes.blue};h3.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h3.shape={composition:'frame',density:'medium',tilt:0,seed:306}
  const h4=makeRecipe({title:'境界を\n越えて。',subtitle:''},'square','slice',0,250928)
  h4.color={paletteId:'acid',...palettes.acid};h4.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h4.shape={composition:'slit',density:'medium',tilt:0,seed:407};h4.motion.amount='normal'
  const h5=makeRecipe({title:'星の\n途中。',subtitle:''},'square','orbit',0,250929)
  h5.color={paletteId:'lilac',...palettes.lilac};h5.type={fontId:'noto-serif-jp-600',align:'center',size:'large',lineHeight:1.15,letterSpacing:0};h5.shape={composition:'eclipse',density:'medium',tilt:0,seed:508};h5.motion.amount='normal'
  const h6=makeRecipe({title:'まだ、\n響いてる。',subtitle:''},'square','echo',0,250930)
  h6.color={paletteId:'mono',...palettes.mono};h6.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h6.shape={composition:'trail',density:'medium',tilt:0,seed:609};h6.motion.amount='normal'
  const h7=makeRecipe({title:'波形の\n向こうへ。',subtitle:''},'square','current',0,250931)
  h7.color={paletteId:'royal',...palettes.royal};h7.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h7.shape={composition:'tide',density:'high',tilt:0,seed:710};h7.motion.amount='normal'
  const h8=makeRecipe({title:'まだ、\nほどけない。',subtitle:''},'square','lattice',0,250932)
  h8.color={paletteId:'cinder',...palettes.cinder};h8.type={fontId:'noto-sans-jp-700',align:'center',size:'large',lineHeight:1.15,letterSpacing:0};h8.shape={composition:'stringfan',density:'high',tilt:0,seed:811};h8.motion.amount='normal'
  const h9=makeRecipe({title:'言葉は\n増幅する。',subtitle:''},'square','glyph',0,250933)
  h9.color={paletteId:'carbon',...palettes.carbon};h9.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h9.shape={composition:'rift',density:'high',tilt:0,seed:912};h9.motion.amount='normal'
  const h10=makeRecipe({title:'この先、\n加速する。',subtitle:''},'square','monolith',0,250934)
  h10.color={paletteId:'obsidian',...palettes.obsidian};h10.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h10.shape={composition:'extrude',density:'high',tilt:0,seed:1013};h10.motion.amount='normal'
  const h11=makeRecipe({title:'視線を\n揺らす。',subtitle:''},'square','interference',0,250935)
  h11.color={paletteId:'volt',...palettes.volt};h11.type={fontId:'noto-sans-jp-700',align:'center',size:'large',lineHeight:1.15,letterSpacing:0};h11.shape={composition:'concentric',density:'high',tilt:0,seed:1114};h11.motion.amount='normal'
  const h12=makeRecipe({title:'輪郭は\nほどける。',subtitle:''},'square','scatter',0,250936)
  h12.color={paletteId:'ultramarine',...palettes.ultramarine};h12.type={fontId:'noto-sans-jp-700',align:'left',size:'large',lineHeight:1.15,letterSpacing:0};h12.shape={composition:'cloud',density:'high',tilt:0,seed:1215};h12.motion.amount='normal'
  return [h1,h2,h3,h4,h5,h6,h7,h8,h9,h10,h11,h12]
}
