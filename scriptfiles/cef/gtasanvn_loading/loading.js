'use strict';
const logo = document.getElementById('logo');
const image = logo.querySelector('.color');
const cef = window.cef;
const fill = amount => logo.style.setProperty('--fill', (100 - amount) + '%');
let complete = false;
function assetReady() {
  if (complete) return;
  fill(46);
  if (cef?.emit) cef.emit('loading:assetReady');
  else if (new URLSearchParams(location.search).has('demo')) setTimeout(() => fill(100), 900);
}
cef?.on('loading:complete', () => {
  if (complete) return;
  complete = true;
  fill(100);
});
if (image.complete && image.naturalWidth) requestAnimationFrame(assetReady);
else image.addEventListener('load', assetReady, {once:true});
