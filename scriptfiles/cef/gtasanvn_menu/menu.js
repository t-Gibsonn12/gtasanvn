'use strict';
const $ = id => document.getElementById(id);
const demo = !window.cef && new URLSearchParams(location.search).has('demo');
const emit = action => window.cef?.emit('mainMenu:action', action);
let stage = -1;
const items = [
  ['Nhiệm vụ','☷',29,19,() => { show('missions'); emit(1); }],
  ['Điểm danh','✓',71,19,() => show('attendance')],
  ['Hướng dẫn','?',88,50,() => emit(3)],
  ['Sự kiện','☆',71,81,() => show('events')],
  ['Túi đồ','▤',29,81,() => emit(4)],
  ['Điện thoại','▯',12,50,() => emit(5)]
];
function node(tag, text, css='') {
  const result = document.createElement(tag);
  result.textContent = text;
  result.className = css;
  return result;
}
for (const [name,icon,x,y,action] of items) {
  const button = node('button','','tile');
  button.style.setProperty('--x', x+'%');
  button.style.setProperty('--y', y+'%');
  button.append(node('span', icon),node('b',name));
  button.onclick = action;
  $('wheel').append(button);
}
function main() { $('panel').hidden=true; $('wheel').hidden=false; }
function show(page) {
  $('wheel').hidden=true; $('panel').hidden=false; $('notice').hidden=true;
  const body=$('content'); body.replaceChildren();
  $('progress').textContent='';
  if (page==='missions') {
    $('title').textContent='Nhiệm vụ newbie';
    $('progress').textContent=stage < 0 ? '…' : Math.min(3,stage)+'/3';
    const list=node('ol','','steps');
    ['Mua xe Bobcat','Làm căn cước','Mở tài khoản ngân hàng'].forEach((name,i) => {
      list.append(node('li',(i<stage?'✓  ':i===stage?'›  ':'○  ')+name,i<stage?'done':i===stage?'current':''));
    });
    const gps=node('button','Đặt GPS','action');
    gps.disabled=stage<0||stage>=3;
    gps.onclick=() => emit(2);
    body.append(list,gps);
    if (stage<0) body.append(node('p','Đang tải tiến độ nhân vật.','muted'));
  } else if (page==='attendance') {
    $('title').textContent='Điểm danh';
    const days=node('div','','days');
    for (let i=1;i<=7;i++) days.append(node('span',String(i)));
    const claim=node('button','Điểm danh hôm nay','action'); claim.disabled=true;
    body.append(days,node('p','Tính năng điểm danh chưa mở.','muted'),claim);
  } else {
    $('title').textContent='Sự kiện';
    body.append(node('p','Chưa có sự kiện được công bố.','muted'));
  }
  $('panel').dataset.page=page;
}
function close() { if(demo) $('menu').hidden=true; else emit(0); }
$('back').onclick=main;
document.querySelector('[data-close]').onclick=close;
document.addEventListener('keydown', e => {
  if (!$('menu').hidden && e.key==='Escape') { e.preventDefault(); close(); }
});
window.cef?.on('mainMenu:show', value => {
  stage=Number(value); $('menu').hidden=false; main();
});
window.cef?.on('mainMenu:hide', () => { $('menu').hidden=true; });
window.cef?.on('mainMenu:stage', value => {
  stage=Number(value);
  if (!$('panel').hidden && $('panel').dataset.page==='missions') show('missions');
});
window.cef?.on('mainMenu:notice', text => { $('notice').textContent=text; $('notice').hidden=false; });
if (demo) { stage=1; $('menu').hidden=false; }
