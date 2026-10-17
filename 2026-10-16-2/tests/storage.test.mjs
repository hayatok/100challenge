import assert from 'node:assert/strict';
import test from 'node:test';
import { safeURL, escapeHTML } from '../app/src/storage.js';
test('external references allow only http and https',()=>{
  for(const value of ['javascript:alert(1)','file:///etc/passwd','data:text/html,x','/relative',null])assert.equal(safeURL(value),null);
  assert.equal(safeURL('https://www.e-stat.go.jp/'),'https://www.e-stat.go.jp/');
  assert.equal(safeURL('http://example.com/'),'http://example.com/');
});
test('source titles and quotations cannot become markup',()=>{
  assert.equal(escapeHTML('<img src=x onerror="x"> & \'文\''),'&lt;img src=x onerror=&quot;x&quot;&gt; &amp; &#39;文&#39;');
  assert.equal(escapeHTML(null),'');
  assert.equal(escapeHTML(1900),'1900');
});
