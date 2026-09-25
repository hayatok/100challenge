import { graphemes } from '../domain/project'
export function displayLines(text:string,aspect:'landscape'|'portrait'):string[]{
  if(text.includes('\n'))return text.split('\n')
  const chars=graphemes(text),limit=aspect==='portrait'?4:6
  if(!/[ぁ-んァ-ン一-龯]/.test(text)||chars.length<=limit)return[text]
  const lines:string[]=[];let remaining=chars
  while(remaining.length>limit){const max=Math.min(limit,remaining.length-1);let cut=max
    let best=Infinity
    for(let i=2;i<=max;i++)if(/[、。がはをにでへと]/.test(remaining[i-1])){
      const tail=remaining.slice(i).join(''),score=Math.abs(i-tail.length)+(tail.length<=2?4:0)+(/^(なる|する|した|ない)/.test(tail)?3:0)
      if(score<best){best=score;cut=i}
    }
    lines.push(remaining.slice(0,cut).join(''));remaining=remaining.slice(cut)
  }
  lines.push(remaining.join(''));return lines
}
