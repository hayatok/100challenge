import assert from 'node:assert/strict';

// Read the live Godot controls, then send ordinary mouse input to the real canvas.
// This helper never changes the game snapshot, scene tree, or DOM state.
export function uiControls(page){
 async function control(id,{allowDisabled=false,timeout=10000}={}){
  assert.equal(typeof id,'string','control ID is a string');
  await page.waitForFunction(({id,allowDisabled})=>{
   const rows=window.echoWitchSnapshot?.gui?.controls;
   return Array.isArray(rows)&&rows.some(row=>row.id===id&&(allowDisabled||row.disabled===false));
  },{id,allowDisabled},{timeout});
  const rows=await page.evaluate(()=>window.echoWitchSnapshot.gui.controls);
  const matches=rows.filter(row=>row.id===id);
  assert.equal(matches.length,1,'exactly one visible live control for '+id);
  const row=matches[0];
  assert.equal(typeof row.label,'string','live control has a label: '+id);
  assert.equal(typeof row.disabled,'boolean','live control has a disabled state: '+id);
  assert.ok(allowDisabled||!row.disabled,'live control is enabled: '+id);
  for(const field of ['x','y','width','height'])assert.ok(Number.isFinite(row[field]),'finite control '+field+': '+id);
  assert.ok(row.width>0&&row.height>0&&row.x>=0&&row.y>=0&&row.x+row.width<=1280.01&&row.y+row.height<=720.01,'live control stays inside the logical viewport: '+id);
  return row;
 }
 async function click(id,options={}){
  const row=await control(id,options);
  const canvas=await page.locator('#canvas').boundingBox();
  assert.ok(canvas&&canvas.width>0&&canvas.height>0,'real game canvas is visible');
  await page.mouse.click(canvas.x+(row.x+row.width/2)*canvas.width/1280,canvas.y+(row.y+row.height/2)*canvas.height/720);
  return row;
 }
 return {control,click};
}
