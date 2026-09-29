import test from 'node:test';
import assert from 'node:assert/strict';
import * as T from 'three';
import { buildStation } from '../src/station.ts';
import { STAGE_STOPS } from '../src/rail.ts';

function withStation(run: (station: ReturnType<typeof buildStation>) => void): void {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'document');
  Object.defineProperty(globalThis, 'document', { configurable: true, value: {
    createElement: () => ({ width: 0, height: 0, getContext: () => ({
      fillStyle: '', textAlign: '', textBaseline: '', font: '',
      fillRect() {}, fillText() {},
    }) }),
  } });
  try { const station = buildStation(); try { run(station); } finally { station.dispose(); } }
  finally {
    if (previous) Object.defineProperty(globalThis, 'document', previous);
    else Reflect.deleteProperty(globalThis, 'document');
  }
}

function stationBoxes(root: T.Group): { name: string; bounds: T.Box3 }[] {
  root.updateMatrixWorld(true);
  const result: { name: string; bounds: T.Box3 }[] = [];
  const unit = new T.Box3(new T.Vector3(-.5,-.5,-.5),new T.Vector3(.5,.5,.5));
  root.traverse(object => {
    if (!(object instanceof T.Mesh) || !(object.geometry instanceof T.BoxGeometry)) return;
    if (object instanceof T.InstancedMesh) {
      const local = new T.Matrix4();
      for (let i=0;i<object.count;i++) {
        object.getMatrixAt(i,local);
        result.push({name:(object.userData.parts as string[] | undefined)?.[i] ?? object.name,
          bounds:unit.clone().applyMatrix4(object.matrixWorld.clone().multiply(local))});
      }
    } else result.push({name:object.name,bounds:unit.clone().applyMatrix4(object.matrixWorld)});
  });
  return result;
}

function intersectsTube(bounds:T.Box3,a:[number,number],b:[number,number]):boolean {
  // The route tube is 0.65m wide and occupies y=.2..2.7.
  if(bounds.max.y<=.2 || bounds.min.y>=2.7)return false;
  const minX=bounds.min.x-.65,maxX=bounds.max.x+.65;
  const minZ=bounds.min.z-.65,maxZ=bounds.max.z+.65;
  let lo=0,hi=1;
  for(const [p,d,min,max] of [[a[0],b[0]-a[0],minX,maxX],[a[1],b[1]-a[1],minZ,maxZ]]) {
    if(Math.abs(d)<1e-8){if(p<min||p>max)return false;continue;}
    const u=(min-p)/d,v=(max-p)/d;
    lo=Math.max(lo,Math.min(u,v));hi=Math.min(hi,Math.max(u,v));
    if(lo>hi)return false;
  }
  return true;
}

test('both station branches and platform have a clear camera tube',()=>withStation(station=>{
  const boxes=stationBoxes(station.root);
  const stop=STAGE_STOPS.station;
  const common:[[number,number],[number,number]][]=[
    [[stop.entrance.x,stop.entrance.z],[stop.forecourt.x,stop.forecourt.z]],
    [[stop.forecourt.x,stop.forecourt.z],[stop.concourse.x,stop.concourse.z]],
  ];
  for(const [area,x] of [['waiting',112],['maintenance',88]] as const){
    const segments=[...common,
      [[100,-6],[100,-12]], [[100,-12],[x,-12]], [[x,-12],[x,-18]],
      [[x,-18],[x,-28]], [[x,-28],[100,-28]], [[100,-28],[100,-36]],
      [[100,-36],[100,-48]], [[100,-48],[100,-61]],
    ] as [[number,number],[number,number]][];
    for(const [a,b] of segments){
      const hits=boxes.filter(item=>intersectsTube(item.bounds,a,b));
      assert.deepEqual(hits.map(item=>item.name),[],`${area} route ${a} → ${b}`);
    }
  }
  for(const name of ['Ticket gate solid housing','Train volumetric body',
    'Train recessed window shadow','Train sliding door recess','Steel running rail',
    'Platform canopy post','Maintenance electrical cabinet','Waiting bench white seat']) {
    assert.ok(boxes.some(item=>item.name===name),name);
  }
  for(const fixtures of Object.values(station.fixtures)) assert.ok(fixtures.length<=4);
}));
