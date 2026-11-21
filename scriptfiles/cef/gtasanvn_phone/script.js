(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  const cef = window.cef;
  const demo = !cef && new URLSearchParams(location.search).has('demo');
  const catalog = [
    ['calls','☎','Điện thoại'],['sms','✉','Tin nhắn'],['map','⌖','Bản đồ'],
    ['feed','▤','Bảng tin'],['jobs','▣','Công việc'],['profile','◉','Hồ sơ'],
    ['vehicles','◇','Kho xe'],['camera','▧','Máy ảnh'],['settings','⚙','Cài đặt'],
    ['contacts','☷','Danh bạ'],['bank','▥','Ngân hàng']
  ];
  const titles = Object.fromEntries(catalog.map(([id,, title]) => [id,title]));
  const data = { number:0, bank:0, name:'', cash:0, level:0, hours:0, license:0,
    stage:-1, peer:0, job:null, contacts:[], history:[], posts:[], vehicles:[], comments:[] };
  let current = '', selectedPost = 0, toastTimer, lockTouch = null;
  let alertData = null, posting = false, postTimer;
  const money = n => new Intl.NumberFormat('vi-VN').format(Number(n)) + ' $';
  const notedApps = ['sms','calls'];
  const asBool = value => value === true || Number(value) === 1;
  const validNumber = text => /^\d{1,9}$/.test(text) && Number(text) > 0 ? Number(text) : 0;
  function make(tag, text='', cls='') {
    const el = document.createElement(tag);
    if (cls) el.className = cls;
    el.textContent = text;
    return el;
  }
  function button(text, action, main=false) {
    const b = make('button', text, main ? 'action primary' : 'action');
    b.type = 'button';
    b.onclick = action;
    return b;
  }
  function field(placeholder, type='text', max=240) {
    const f = make(type === 'area' ? 'textarea' : 'input', '', 'field');
    if (type !== 'area') f.type = type === 'number' ? 'text' : type;
    if (type === 'number') f.inputMode = 'numeric';
    f.placeholder = placeholder;
    f.setAttribute('aria-label', placeholder);
    f.maxLength = max;
    return f;
  }
  function card(title, detail) {
    const el = make('article', '', 'card');
    el.append(make('strong', title));
    if (detail != null) el.append(make('p', detail, 'subtle'));
    return el;
  }
  const emit = (event,...args) => {
    if (cef && typeof cef.emit === 'function') cef.emit(event,...args);
    else if (demo) note('Bản xem trước. Thao tác này cần máy chủ.');
  };
  function note(text) {
    if (!$('phone').hidden) {
      $('toast').textContent = text;
      $('toast').hidden = false;
      clearTimeout(toastTimer);
      toastTimer = setTimeout(() => { $('toast').hidden = true; }, 4500);
    }
  }
  function view(name) {
    current = name;
    $('lock').hidden = name !== 'lock';
    $('home').hidden = name !== 'home';
    $('app').hidden = name === 'lock' || name === 'home';
    $('toast').hidden = true;
    $('phone').classList.toggle('app-open', !$('app').hidden);
    if (!$('app').hidden) {
      $('title').textContent = titles[name] || 'Bình luận';
      render();
    }
  }
  function open(name) {
    view(name);
    const event = {sms:'phone:history',map:'phone:history',feed:'iphone:feed',jobs:'phone:jobs',
      profile:'phone:profile',vehicles:'phone:vehicles',contacts:'phone:contacts',bank:'phone:refresh'}[name];
    if (event && !demo) emit(event);
  }
  function close() {
    if (demo) return view('lock');
    emit('phone:close');
  }
  function render() {
    const content = $('content');
    content.replaceChildren();
    const homes = {
      calls: renderCalls, sms: renderMessages, map: renderMap, feed: renderFeed,
      comments: renderComments, contacts: renderContacts, jobs: renderJobs,
      vehicles: renderVehicles, profile: renderProfile, bank: renderBank,
      settings: renderSettings, camera: renderCamera
    };
    homes[current]?.(content);
  }
  function refreshList(id, renderItems) {
    const container = $(id);
    if (container) {
      container.replaceChildren();
      renderItems(container);
    }
  }
  function renderCalls(c) {
    const number = field('Số điện thoại', 'number', 9);
    const state = make('p', '', 'subtle');
    state.id = 'call-state';
    c.append(number, button('Gọi', () => {
      const value = validNumber(number.value.trim());
      if (value) emit('phone:call', value); else note('Nhập số điện thoại hợp lệ.');
    },true), button('Nghe máy', () => emit('phone:pickup')),
    button('Cúp máy', () => emit('phone:hangup')), state);
    renderCallState();
  }
  function renderCallState() {
    const state = $('call-state');
    if (!state) return;
    state.textContent = data.stage === 1 ? 'Cuộc gọi đến · ' + data.peer :
      data.stage === 2 ? 'Đang gọi · ' + data.peer :
      data.stage !== -1 ? 'Đang kết nối · ' + data.peer : 'Chưa có cuộc gọi.';
  }
  function renderMessages(c) {
    const number = field('Số người nhận','number',9), body = field('Tin nhắn','area');
    c.append(number,body,button('Gửi',() => {
      const to = validNumber(number.value.trim());
      const message = body.value.trim();
      if (!to || !message) return note('Nhập số người nhận và nội dung.');
      emit('phone:sms',to,message);
    },true),button('Gửi vị trí hiện tại',() => {
      const to = validNumber(number.value.trim());
      if (to) emit('phone:sendPosition',to); else note('Nhập số người nhận.');
    }));
    c.append(make('h2','Gần đây'));
    const list=make('div'); list.id='message-list'; c.append(list);
    refreshList('message-list',renderMessageItems);
  }
  function renderMessageItems(c, onlyMap=false) {
    const rows = onlyMap ? data.history.filter(row => row.position) : data.history;
    if (!rows.length) c.append(make('p',onlyMap ? 'Chưa có vị trí được chia sẻ.' : 'Chưa có tin nhắn.','subtle'));
    for (const row of rows) {
      const heading = row.from === data.number ? 'Đến ' + row.to : 'Từ ' + row.from;
      const entry = card(heading,row.position ? 'Vị trí đã chia sẻ' : row.text);
      if (row.position) entry.append(button('Đặt điểm đến',() => emit('phone:waypoint',row.id),true));
      c.append(entry);
    }
  }
  function renderMap(c) {
    c.append(button('Điểm nhận việc Pizza',() => emit('phone:pizza',0),true));
    const list=make('div'); list.id='map-list'; c.append(list);
    refreshList('map-list', el => renderMessageItems(el,true));
  }
  function renderFeed(c) {
    const body = field('Chia sẻ điều gì đó','area'), photo = field('Link ảnh HTTPS','url',500);
    c.append(body,photo,button('Đăng bài',() => {
      if (posting) return;
      const link = photo.value.trim();
      if (!body.value.trim() && !link) return note('Nhập bài viết hoặc link ảnh.');
      if (link && !safePhoto(link)) return note('Link ảnh cần dùng HTTPS.');
      posting = true;
      emit('iphone:post',body.value.trim(),link);
      postTimer=setTimeout(() => { posting=false; if(current==='feed') note('Máy chủ chưa phản hồi.'); },9000);
    },true));
    photo.id='post-photo'; body.id='post-body';
    const list=make('div'); list.id='feed-list'; c.append(list);
    refreshList('feed-list',renderPostItems);
  }
  function safePhoto(text) {
    try {
      const url = new URL(text);
      return url.protocol === 'https:' && !url.username && !url.password;
    } catch { return false; }
  }
  function renderPostItems(list) {
    for (const post of data.posts) {
      const el = card(post.name,post.body);
      if (safePhoto(post.photo)) {
        const img = make('img','','social-photo');
        img.referrerPolicy='no-referrer'; img.loading='lazy'; img.alt='Ảnh bài đăng'; img.src=post.photo;
        img.onerror=() => img.remove();
        el.append(img);
      }
      const like=button((post.liked?'Đã thích':'Thích')+' · '+post.likes,() => emit('iphone:like',post.id));
      like.disabled=post.liked;
      el.append(like,button('Bình luận',() => {
        selectedPost=post.id; data.comments=[]; view('comments'); emit('iphone:comments',post.id);
      }));
      list.append(el);
    }
  }
  function renderComments(c) {
    const post=data.posts.find(p => p.id===selectedPost), comment=field('Bình luận','area');
    if (post) c.append(card(post.name,post.body));
    c.append(comment,button('Gửi bình luận',() => {
      const text=comment.value.trim();
      if(text) emit('iphone:comment',selectedPost,text);
    },true));
    comment.id='comment-body';
    const list=make('div'); list.id='comments-list'; c.append(list);
    refreshList('comments-list',renderCommentItems);
  }
  function renderCommentItems(c) {
    for(const comment of data.comments) c.append(card(comment.author,comment.body));
  }
  function renderContacts(c) {
    const name=field('Tên liên hệ','text',48), number=field('Số điện thoại','number',9);
    c.append(name,number,button('Lưu liên hệ',() => {
      const value=validNumber(number.value.trim());
      if(name.value.trim() && value) emit('phone:contactAdd',name.value.trim(),value);
      else note('Nhập tên và số điện thoại.');
    },true));
    const list=make('div'); list.id='contact-list'; c.append(list);
    refreshList('contact-list',renderContactItems);
  }
  function renderContactItems(c) {
    for(const row of data.contacts) {
      const el=card(row.name,row.number);
      el.append(button('Gọi',() => { open('calls'); emit('phone:call',row.number); }),button('Xóa',() => emit('phone:contactDelete',row.id)));
      c.append(el);
    }
  }
  function renderJobs(c) {
    const j = data.job;
    if (!j) return c.append(make('p','Đang tải công việc…','subtle'));
    c.append(card(j.main,'Nghề hiện tại'));
    const pizza=card('Pizza Stack',j.active ? 'Đang giao hàng · Đã giao ' + j.seconds + ' đơn trong ca' : j.eligible ? 'Có thể nhận bánh tại điểm làm việc.' : 'Đến điểm làm việc để tìm hiểu nghề.');
    pizza.append(button('Đến điểm nhận việc',() => emit('phone:pizza',0),true));
    if (j.eligible && !j.active) pizza.append(button('Tương tác với ca pizza',() => emit('phone:pizza',1)));
    c.append(pizza,card('Thu nhập ca',money(j.paycheck)));
  }
  function renderVehicles(c) {
    if (!data.vehicles.length) c.append(make('p','Chưa có xe sở hữu khả dụng.','subtle'));
    for (const v of data.vehicles) {
      const status = ['Đã cất','Đang hoạt động','Tạm giữ','Hư hỏng'][v.storage] || 'Chưa rõ';
      const el=card(v.name,v.plate+' · '+status+' · Xăng '+v.fuel+'%');
      if (v.storage === 0 || v.storage === 1) {
        el.append(button('Định vị xe',() => emit('phone:vehicleLocate',v.id,v.db),true));
        if (v.storage === 1) el.append(button('Cất xe',() => emit('phone:vehicleStorage',v.id,v.db,0)));
        else el.append(button('Lấy xe',() => emit('phone:vehicleStorage',v.id,v.db,1),true));
        if(v.driving) el.append(button('Lưu chỗ đỗ',() => emit('phone:vehiclePark',v.id,v.db)));
      }
      c.append(el);
    }
  }
  function renderProfile(c) {
    c.append(card(data.name || 'Đang tải…',data.number || ''),
      card('Cấp '+data.level,'Pin điện thoại '+data.hours+'%'),
      card('Tiền mặt',money(data.cash)),card('Tài khoản ngân hàng',money(data.bank)));
  }
  function renderBank(c) {
    c.append(card('Số dư',money(data.bank)));
  }
  function renderSettings(c) {
    c.append(card('Số điện thoại',data.number || '–'),button('Khóa màn hình',() => view('lock'),true),button('Đổi chế độ im lặng',() => emit('phone:settings',0)),button('Tắt điện thoại',() => emit('phone:settings',1)));
  }
  function renderCamera(c) {
    c.append(card('Chia sẻ ảnh nhân vật','Chụp ảnh trong game, tải ảnh lên HTTPS rồi dán link khi đăng bài.'),
      button('Mở ứng dụng Bảng tin',() => open('feed'),true));
  }
  function setAlert(title,body) {
    const alert = $('alert'), lockAlert = $('lock-alert');
    alertData={title, body};
    alert.querySelector('strong').textContent=title; alert.querySelector('p').textContent=body;
    lockAlert.querySelector('strong').textContent=title; lockAlert.querySelector('span').textContent=body;
    lockAlert.hidden=false;
    alert.hidden=!$('phone').hidden;
    if (!$('phone').hidden && current!=='lock') note(title);
  }
  function show() { $('phone').hidden=false; $('alert').hidden=true; view('lock'); }
  function hide() { $('phone').hidden=true; $('alert').hidden=true; }
  function clock() {
    const d = new Date(), time = d.toLocaleTimeString('vi-VN',{hour:'2-digit',minute:'2-digit'});
    $('time').textContent=time; $('big-time').textContent=time;
    $('date').textContent=d.toLocaleDateString('vi-VN',{weekday:'long',month:'long',day:'numeric'});
  }
  for (const [key, icon, title] of catalog) {
    const b=make('button','','app-icon');
    const symbol=make('span',icon); symbol.setAttribute('aria-hidden','true');
    b.append(symbol,document.createTextNode(title)); b.onclick=() => open(key); $('apps').append(b);
  }
  $('close').onclick=close; $('unlock').onclick=() => view('home');
  $('home-button').onclick=() => view('home');
  $('back').onclick=() => current==='comments' ? open('feed') : view('home');
  $('lock-alert').onclick=() => alertData && open(notedApps[data.stage===1 ? 1 : 0]);
  $('lock').addEventListener('pointerdown',e => { lockTouch=e.clientY; });
  $('lock').addEventListener('pointerup',e => { if(lockTouch!==null && lockTouch-e.clientY>45) view('home'); lockTouch=null; });
  document.addEventListener('keydown',e => { if(e.key==='Escape' && !$('phone').hidden) { e.preventDefault(); close(); } });
  clock(); setInterval(clock,15000);
  if (cef && typeof cef.on==='function') {
    cef.on('phone:open',show); cef.on('phone:closed',hide);
    cef.on('phone:alert',setAlert); cef.on('phone:alertClear',() => { $('alert').hidden=true; });
    cef.on('phone:notice',note); cef.on('phone:error',msg => { posting=false; clearTimeout(postTimer); note(msg); });
    cef.on('phone:state',(number,bank,name) => {
      Object.assign(data,{number:Number(number),bank:Number(bank),name:String(name)});
      if(['bank','profile','settings'].includes(current)) render();
    });
    cef.on('phone:profileData',(cash,level,hours,license) => {
      Object.assign(data,{cash,level,hours,license:asBool(license)}); if(current==='profile') render();
    });
    cef.on('phone:jobData',(main,side,eligible,seconds,active,paycheck) => {
      data.job={main,side,eligible:asBool(eligible),seconds,active:asBool(active),paycheck}; if(current==='jobs') render();
    });
    cef.on('phone:vehiclesClear',() => { data.vehicles=[]; });
    cef.on('phone:vehicleItem',(id,db,name,plate,fuel,driving,storage) => { data.vehicles.push({id,db,name,plate,fuel,driving:asBool(driving),storage:Number(storage)}); });
    cef.on('phone:vehiclesDone',() => { if(current==='vehicles') render(); });
    cef.on('phone:callState',(stage,peer) => { data.stage=Number(stage); data.peer=Number(peer); renderCallState(); });
    cef.on('phone:contactsClear',() => { data.contacts=[]; });
    cef.on('phone:contactItem',(id,name,number) => { data.contacts.push({id,name,number}); });
    cef.on('phone:contactsDone',() => refreshList('contact-list',renderContactItems));
    cef.on('phone:historyClear',() => { data.history=[]; });
    cef.on('phone:historyItem',(id,from,to,text,position) => {
      data.history.push({id,from:Number(from),to:Number(to),text,position:asBool(position)});
    });
    cef.on('phone:historyDone',() => {
      refreshList('message-list',renderMessageItems); refreshList('map-list', el => renderMessageItems(el,true));
    });
    cef.on('iphone:feedClear',() => { data.posts=[]; });
    cef.on('iphone:postItem',(id,name,body,photo,likes,liked) => {
      data.posts.push({id,name,body,photo,likes,liked:asBool(liked)});
    });
    cef.on('iphone:feedDone',() => refreshList('feed-list',renderPostItems));
    cef.on('iphone:postResult',(ok,msg) => {
      clearTimeout(postTimer); posting=false;
      if (asBool(ok) && $('post-body')) { $('post-body').value=''; $('post-photo').value=''; }
      note(msg);
    });
    cef.on('iphone:commentsClear',post => { if(Number(post)===Number(selectedPost)) data.comments=[]; });
    cef.on('iphone:commentItem',(post,author,body) => {
      if(Number(post)===Number(selectedPost)) data.comments.push({author,body});
    });
    cef.on('iphone:commentsDone',post => {
      if(Number(post)!==Number(selectedPost)) return;
      if($('comment-body')) $('comment-body').value='';
      refreshList('comments-list',renderCommentItems);
    });
    emit('phone:ready');
  } else if (demo) {
    Object.assign(data,{
      name:'Minh Nguyen',number:280821, bank:28950, cash:490, level:4,hours:12,license:true,
      job:{main:'Giao pizza',side:'Không',eligible:true,seconds:38,active:true,paycheck:135},
      vehicles:[{id:8,db:20,name:'Premier',plate:'LS-2808',fuel:72,driving:true,storage:1}],
      history:[{id:8,from:280833,to:280821,text:'Đón mình ở Idlewood nhé.'},{id:9,from:280833,to:280821,position:true}],
      contacts:[{id:1,name:'Anh Vũ',number:280833}],
      posts:[{id:1,name:'Anh Vũ',body:'Tối nay gặp nhau ở Idlewood nhé.',photo:'',likes:3,liked:false}]
    });
    show(); setAlert('Pizza Stack','Có đơn giao mới.');
  }
})();
