(() => {
  'use strict';
  const $ = id => document.getElementById(id);
  let cef = window.cef;
  const demo = !cef && new URLSearchParams(location.search).has('demo');
  const catalog = [
    ['map','⌖','GPS','blue'],['jobs','▣','Việc làm','amber'],
    ['vehicles','◆','Garage','red'],['bank','▤','Ngân hàng','indigo'],
    ['feed','◎','Mạng xã hội','purple'],['missions','★','Nhiệm vụ','amber'],
    ['inventory','▦','Túi đồ','slate'],['profile','●','Hồ sơ','blue'],
    ['notifications','◉','Thông báo','red'],['services','⌁','Dịch vụ','amber'],['guide','?','Hướng dẫn','indigo'],
    ['settings','⚙','Cài đặt','slate'],
    ['calls','☎','Điện thoại','green'],['sms','✉','Tin nhắn','green'],
    ['contacts','☷','Danh bạ','slate']
  ];
  const titles = Object.fromEntries(catalog.map(([id,, title]) => [id,title]));
  const data = { number:0, bank:0, name:'', cash:0, level:0, license:0,
    stage:-1, peer:0, job:null, contacts:[], history:[], posts:[], vehicles:[], comments:[] };
  Object.assign(data, { tutorial:-1, account:'', battery:null, silent:false, gps:[], position:null,
    transactions:null, notifications:[], unreadMessages:new Map() });
  const missionNames = ['Mua xe Bobcat','Làm căn cước','Mở tài khoản ngân hàng'];
  let current = '', selectedPost = 0, toastTimer, lockTouch = null;
  let alertData = null, posting = false, postTimer, probeTimer, selectedThread = 0, smsDraft = null;
  const money = n => new Intl.NumberFormat('vi-VN').format(Number(n)) + ' $';
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
    if (type === 'number') { f.inputMode = 'tel'; f.autocomplete = 'off'; }
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
    if (cef && typeof cef.emit === 'function') {
      try { cef.emit(event,...args); } catch { note('Không gửi được thao tác tới máy chủ.'); }
    } else note(demo ? 'Đang xem bản demo.' : 'Client chưa cấp kết nối CEF.');
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
    if (name === 'home') renderToday();
    if (!$('app').hidden) {
      $('title').textContent = titles[name] || 'Bình luận';
      render();
    }
  }
  let gpsQuery = '', updateGPS = null;
  function open(name, query='') {
    if (name === 'map') gpsQuery = query;
    if (name === 'sms' && selectedThread) markThreadRead(selectedThread);
    if (name === 'notifications') {
      data.notifications.forEach(item => { item.unread = false; });
      renderBadges();
    }
    view(name);
    if (demo) return;
    const event = {sms:'phone:history',feed:'iphone:feed',jobs:'phone:jobs',
      profile:'phone:profile',vehicles:'phone:vehicles',contacts:'phone:contacts',
      bank:'phone:bankHistory',settings:'phone:hubData',missions:'phone:hubData'}[name];
    if (event) emit(event);
    if (name === 'map') {
      emit('phone:gpsList');
      emit('phone:history');
    }
  }
  function renderToday() {
    const home = $('today');
    home.replaceChildren(make('div','LOS SANTOS','eyebrow'),make('strong',data.name || 'GTASANVN'));
    const target = missionNames[data.tutorial];
    const jump = button(data.stage === 1 ? 'Cuộc gọi đến · ' + data.peer :
      target ? 'Tiếp theo · ' + target : 'Hoạt động của bạn', () =>
      open(data.stage === 1 ? 'calls' : target ? 'missions' : 'notifications'));
    jump.classList.add('jump');
    home.append(jump);
  }
  function renderBadges() {
    const counts = {sms:[...data.unreadMessages.values()].reduce((a,b) => a+b,0),
      notifications:data.notifications.filter(item => item.unread).length, calls:Number(data.stage === 1)};
    for (const [key,count] of Object.entries(counts)) {
      const badge = $('badge-' + key);
      badge.hidden = !count;
      badge.textContent = count > 99 ? '99+' : String(count);
    }
  }
  function markThreadRead(number) {
    data.unreadMessages.delete(Number(number));
    renderBadges();
  }
  function renderMissions(c) {
    const stage = data.tutorial;
    if (stage < 0) return c.append(card('Nhiệm vụ tân thủ','Đang tải tiến độ nhân vật.'));
    c.append(card('Nhiệm vụ tân thủ',Math.min(stage,missionNames.length)+'/'+missionNames.length+' mục đã hoàn thành'));
    for (const [index,name] of missionNames.entries()) {
      const row = card(name, index < stage ? 'Đã hoàn thành' : index === stage ? 'Đang thực hiện' : 'Chưa mở');
      if (index === stage) row.append(button('Đặt GPS',() => emit('phone:hub',3),true));
      c.append(row);
    }
  }
  function renderNotifications(c) {
    if (!data.notifications.length) c.append(card('Chưa có thông báo','Cuộc gọi và tin nhắn trong phiên sẽ hiện ở đây.'));
    for (const item of data.notifications) {
      const row = card(item.title,item.body);
      if (item.app) row.append(button('Mở',() => open(item.app)));
      c.append(row);
    }
  }
  function renderInventory(c) {
    c.append(card('Túi đồ nhân vật','Xem, sử dụng hoặc sắp xếp vật phẩm trong hành trang.'),
      button('Mở túi đồ',() => emit('phone:hub',0),true));
  }
  function renderServices(c) {
    c.append(button('Tìm trạm xăng',() => open('map','Trạm xăng'),true),
      button('Tìm gara sửa xe',() => open('map','Sửa xe')),
      button('Tìm máy ATM',() => open('map','ATM')));
  }
  function renderGuide(c) {
    c.append(button('Theo dõi nhiệm vụ tân thủ',() => open('missions'),true),
      button('Xem hướng dẫn máy chủ',() => emit('phone:hub',1)));
  }
  function close() {
    if (demo) return view('lock');
    emit('phone:close');
  }
  function render() {
    const content = $('content');
    content.replaceChildren();
    updateGPS=null;
    const homes = {
      calls: renderCalls, sms: renderMessages, map: renderMap, feed: renderFeed,
      comments: renderComments, contacts: renderContacts, jobs: renderJobs,
      vehicles: renderVehicles, profile: renderProfile, bank: renderBank,
      settings: renderSettings, missions: renderMissions, notifications: renderNotifications,
      inventory: renderInventory, guide: renderGuide, services: renderServices
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
    const number = field('Số điện thoại','number',9);
    const state = make('p', '', 'subtle');
    state.id = 'call-state';
    number.classList.add('dial-number');
    const keypad = make('div','','dialpad');
    for (const digit of '123456789') {
      keypad.append(button(digit, () => { if(number.value.length<9) number.value += digit; }));
    }
    keypad.append(make('span'),button('0', () => { if(number.value.length<9) number.value += '0'; }));
    keypad.append(button('⌫', () => { number.value=number.value.slice(0,-1); }));
    const call = button('Gọi', () => {
      const value = validNumber(number.value.trim());
      if (value) emit('phone:call', value); else note('Nhập số điện thoại hợp lệ.');
    },true);
    call.id = 'call-start';
    const pickup = button('Nghe máy', () => emit('phone:pickup'),true);
    pickup.id = 'call-pickup';
    const hangup = button('Cúp máy', () => emit('phone:hangup'));
    hangup.id = 'call-hangup';
    c.append(state,number,keypad,call,pickup,hangup);
    number.id = 'call-number';
    keypad.id = 'call-pad';
    const chat=make('div'); chat.id='call-text';
    const text=field('Nói chuyện qua tin nhắn','text',120);
    chat.append(text,button('Gửi trong cuộc gọi', () => {
      if(text.value.trim()) emit('phone:callChat',text.value.trim());
    }));
    c.append(chat);
    renderCallState();
  }
  function renderCallState() {
    const state = $('call-state');
    if (!state) return;
    state.textContent = data.stage === 1 ? 'Cuộc gọi đến · ' + data.peer :
      data.stage === 2 ? 'Đã kết nối · ' + data.peer :
      data.stage !== -1 ? 'Đang gọi · ' + data.peer : 'Bàn phím gọi';
    for (const id of ['call-number','call-pad','call-start']) $(id).hidden = data.stage !== -1;
    $('call-pickup').hidden = data.stage !== 1;
    $('call-hangup').hidden = data.stage === -1;
    $('call-text').hidden = data.stage !== 2;
  }
  function renderMessages(c) {
    const list=make('div'); list.id='message-list'; c.append(list);
    const number = field('Số người nhận','number',9), body = field('Tin nhắn','area');
    number.value = selectedThread ? String(selectedThread) : '';
    c.append(number,body,button('Gửi',() => {
      const to = validNumber(number.value.trim());
      const message = body.value.trim();
      if (!to || !message) return note('Nhập số người nhận và nội dung.');
      smsDraft={to,message};
      emit('phone:sms',to,message);
    },true),button('Gửi vị trí',() => {
      const to = validNumber(number.value.trim());
      if (to) emit('phone:sendPosition',to); else note('Nhập số người nhận.');
    }));
    body.id='sms-body';
    refreshList('message-list',renderMessageItems);
  }
  function renderMessageItems(c, onlyMap=false) {
    const peer = row => row.from === data.number ? row.to : row.from;
    if (!onlyMap && !selectedThread) {
      const latest = new Map();
      for (const row of data.history) if (!latest.has(peer(row))) latest.set(peer(row), row);
      if (!latest.size) c.append(make('p','Chưa có hội thoại.','subtle'));
      for(const [number,row] of latest) {
        const contact=data.contacts.find(person => Number(person.number)===number);
        const count = data.unreadMessages.get(number);
        const entry=card((contact?.name || String(number)) + (count ? ' · '+count+' mới' : ''), row.position ? 'Đã chia sẻ vị trí' : row.text);
        entry.append(button('Mở hội thoại',() => { selectedThread=number; markThreadRead(number); render(); }));
        c.append(entry);
      }
      return;
    }
    if (!onlyMap) c.append(button('Tất cả hội thoại',() => { selectedThread=0; render(); }));
    const rows = onlyMap ? data.history.filter(row => row.position) : data.history.filter(row => peer(row)===selectedThread).reverse();
    if (!rows.length) c.append(make('p',onlyMap ? 'Chưa có vị trí được chia sẻ.' : 'Chưa có tin nhắn.','subtle'));
    for (const row of rows) {
      const outbound=row.from===data.number;
      const entry = card(outbound ? 'Bạn' : String(row.from),row.position ? 'Vị trí đã chia sẻ' : row.text);
      if(!onlyMap) entry.classList.add(outbound?'bubble-out':'bubble-in');
      if (row.position) entry.append(button('Đặt điểm đến',() => emit('phone:waypoint',row.id),true));
      c.append(entry);
    }
  }
  function renderMap(c) {
    const search = field('Tìm địa điểm hoặc ATM');
    search.value = gpsQuery;
    const plot=make('canvas','','gps-plot');
    plot.width=360; plot.height=186;
    plot.setAttribute('aria-label','Sơ đồ vị trí tương đối và điểm đến');
    const destinations=make('div'); destinations.id='gps-list';
    c.append(search,plot,make('p','Sơ đồ vị trí · Bắc ở phía trên','subtle'),destinations,
      button('Hủy GPS',() => emit('phone:hub',4)),
      button('Chia sẻ vị trí',() => open('sms')),
      make('h2','Vị trí đã chia sẻ'));
    const list=make('div'); list.id='map-list'; c.append(list);
    const update=() => {
      const term=normalize(search.value.trim());
      const places=data.gps.filter(p => normalize(p.name+' '+p.category).includes(term))
        .sort((a,b) => a.distance-b.distance);
      destinations.replaceChildren();
      if (!places.length) destinations.append(make('p',data.position?'Không tìm thấy địa điểm.':'Đang tải địa điểm…','subtle'));
      for (const [index,p] of places.entries()) {
        const row=card((index+1)+'. '+p.name,p.category+' · '+p.distance+' m');
        row.append(button('Dẫn đường',() => emit('phone:gpsTo',p.id),true));
        destinations.append(row);
      }
      drawMap(plot,places);
    };
    search.addEventListener('input',update);
    updateGPS=update;
    update();
    refreshList('map-list', el => renderMessageItems(el,true));
  }
  function normalize(value) {
    return value.toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/đ/g,'d');
  }
  function drawMap(canvas, places) {
    const ctx=canvas.getContext('2d');
    const {width,height}=canvas;
    ctx.clearRect(0,0,width,height);
    ctx.strokeStyle='#22384a';
    for(let x=20;x<width;x+=20) { ctx.beginPath();ctx.moveTo(x,0);ctx.lineTo(x,height);ctx.stroke(); }
    for(let y=20;y<height;y+=20) { ctx.beginPath();ctx.moveTo(0,y);ctx.lineTo(width,y);ctx.stroke(); }
    if (!data.position) return;
    const points=[data.position,...places], xs=points.map(p=>p.x), ys=points.map(p=>p.y);
    const left=Math.min(...xs), right=Math.max(...xs), bottom=Math.min(...ys), top=Math.max(...ys);
    const scale=Math.min((width-42)/Math.max(right-left,100),(height-42)/Math.max(top-bottom,100));
    ctx.font='bold 11px system-ui'; ctx.textAlign='center'; ctx.textBaseline='middle';
    for (const [i,p] of points.entries()) {
      const x=width/2 + (p.x-(left+right)/2)*scale, y=height/2 - (p.y-(top+bottom)/2)*scale;
      ctx.beginPath(); ctx.arc(x,y,10,0,2*Math.PI); ctx.fillStyle=i ? '#345477':'#087afc'; ctx.fill();
      ctx.fillStyle='#fff'; ctx.fillText(i ? String(i):'▲',x,y);
    }
  }
  function renderFeed(c) {
    const body = field('Chia sẻ điều gì đó','area'), photo = field('Link ảnh HTTPS','url',500);
    const form = make('details','','card compose');
    form.append(make('summary','Tạo bài viết'),body,photo,button('Đăng bài',() => {
      if (posting) return;
      const link = photo.value.trim();
      if (!body.value.trim() && !link) return note('Nhập bài viết hoặc link ảnh.');
      if (link && !safePhoto(link)) return note('Link ảnh cần dùng HTTPS.');
      posting = true;
      emit('iphone:post',body.value.trim(),link);
      postTimer=setTimeout(() => { posting=false; if(current==='feed') note('Máy chủ chưa phản hồi.'); },9000);
    },true));
    c.append(form);
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
    if (!data.posts.length) list.append(make('p','Chưa có bài viết.','subtle'));
    for (const post of data.posts) {
      const el = card(post.name);
      el.classList.add('social-card');
      if (safePhoto(post.photo)) {
        const img = make('img','','social-photo');
        img.referrerPolicy='no-referrer'; img.loading='lazy'; img.alt='Ảnh bài đăng'; img.src=post.photo;
        img.onerror=() => img.remove();
        el.append(img);
      }
      if(post.body) el.append(make('p',post.body));
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
    const name=field('Tên liên hệ','text',31), number=field('Số điện thoại','number',9);
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
      el.append(button('Gọi',() => { open('calls'); emit('phone:call',row.number); }),button('Nhắn tin',() => { selectedThread=Number(row.number); open('sms'); }),button('Xóa',() => emit('phone:contactDelete',row.id)));
      c.append(el);
    }
  }
  function renderJobs(c) {
    const j = data.job;
    if (!j) return c.append(make('p','Đang tải công việc…','subtle'));
    c.append(card(j.main,'Nghề hiện tại'));
    const pizza=card('Pizza Stack',j.active ? 'Đang giao hàng · Đã giao ' + j.seconds + ' đơn trong ca' : j.eligible ? 'Có thể nhận bánh tại điểm làm việc.' : 'Đến điểm làm việc để tìm hiểu nghề.');
    pizza.append(button('Đến điểm nhận việc',() => emit('phone:pizza',0),true));
    pizza.append(button(j.eligible ? 'Gặp quản lý' : 'Ứng tuyển tại chỗ',() => emit('phone:pizza',1)));
    if (j.active) pizza.append(button('Nhận đơn giao tiếp theo',() => emit('phone:pizza',2),true));
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
    c.append(card(data.name || 'Đang tải…',data.number ? 'Số điện thoại · '+data.number : ''),
      card('Cấp '+data.level,data.license ? 'Đã có căn cước' : 'Chưa có căn cước'),
      card('Tiền mặt',money(data.cash)),card('Tài khoản ngân hàng',money(data.bank)));
  }
  function renderBank(c) {
    const balance=card('LS Bank',data.account || 'Số dư nhân vật');
    balance.classList.add('bank-card');
    balance.append(make('div',money(data.bank),'balance'));
    c.append(balance,button('Giao dịch tại ATM',() => emit('phone:hub',2),true),
      button('Tìm ATM',() => open('map','ATM')),make('h2','Giao dịch gần đây'));
    const types={atm_deposit:'Nạp tiền',atm_withdraw:'Rút tiền',bank_transfer_in:'Nhận tiền',bank_transfer_out:'Chuyển tiền'};
    if (data.transactions == null) return c.append(make('p','Đang tải giao dịch…','subtle'));
    if (!data.transactions.length) c.append(make('p','Chưa có giao dịch ATM.','subtle'));
    for (const item of data.transactions) {
      const debit = item.kind === 'atm_withdraw' || item.kind === 'bank_transfer_out';
      const row = card(types[item.kind], item.date);
      row.append(make('strong',(debit ? '−' : '+')+money(Math.abs(item.amount)),debit?'debit':'credit'));
      c.append(row);
    }
  }
  function renderSettings(c) {
    c.append(card(data.name || 'Điện thoại', 'Số điện thoại · '+(data.number || '–')),
      card('Pin',data.battery == null ? 'Đang tải…' : data.battery+'%'),card('Vị trí điện thoại'),
      button('Giữa màn hình',() => setPosition('center'),!$('phone').classList.contains('at-left')),
      button('Góc trái',() => setPosition('left'),$('phone').classList.contains('at-left')),
      button('Khóa màn hình',() => view('lock'),true),
      button(data.silent ? 'Tắt im lặng' : 'Bật im lặng',() => emit('phone:settings',0)),
      button('Tắt điện thoại',() => emit('phone:settings',1)));
  }
  function setAlert(title,body,app=null) {
    const alert = $('alert'), lockAlert = $('lock-alert');
    alertData={title, body, app, unread:current!=='notifications' || $('phone').hidden};
    data.notifications.unshift(alertData);
    data.notifications.length=Math.min(30,data.notifications.length);
    renderBadges();
    if (current==='notifications') render();
    alert.querySelector('strong').textContent=title; alert.querySelector('p').textContent=body;
    lockAlert.querySelector('strong').textContent=title; lockAlert.querySelector('span').textContent=body;
    lockAlert.hidden=false;
    alert.hidden=!$('phone').hidden;
    if (!$('phone').hidden && current!=='lock') note(title);
  }
  function setPosition(position, refresh=true) {
    $('phone').classList.toggle('at-left',position==='left');
    try { localStorage.setItem('gtasanvn-phone-position',position); } catch {}
    if (refresh && current==='settings') render();
  }
  function probe() {
    if(demo) return;
    clearTimeout(probeTimer);
    $('connection').textContent='Đang kết nối';
    probeTimer=setTimeout(() => {
      $('connection').textContent='Chưa phản hồi';
      note('CEF chưa nhận phản hồi từ server. Kiểm tra phiên bản client và log server.');
    },4500);
    emit('phone:probe');
  }
  function show() {
    const reopen=!$('phone').hidden;
    $('phone').hidden=false; $('alert').hidden=true;
    document.body.classList.add('phone-visible');
    if (!reopen) view('lock');
    try { if (cef && typeof cef.set_focus==='function') cef.set_focus(true); } catch {}
    probe();
    if (!demo) emit('phone:hubData');
  }
  function hide() {
    clearTimeout(probeTimer);
    $('phone').hidden=true; $('alert').hidden=true;
    current=''; selectedThread=0; smsDraft=null;
    document.body.classList.remove('phone-visible');
  }
  function clock() {
    const d = new Date(), time = d.toLocaleTimeString('vi-VN',{hour:'2-digit',minute:'2-digit'});
    $('time').textContent=time; $('big-time').textContent=time;
    $('date').textContent=d.toLocaleDateString('vi-VN',{weekday:'long',month:'long',day:'numeric'});
  }
  for (const [key, icon, title, tone] of catalog) {
    const b=make('button','','app-icon');
    b.dataset.tone=tone;
    const symbol=make('span',icon,'app-glyph'); symbol.setAttribute('aria-hidden','true');
    const badge=make('sup','','badge'); badge.id='badge-'+key; badge.hidden=true;
    b.append(symbol,document.createTextNode(title),badge);
    b.onclick=() => open(key);
    $(['calls','sms','contacts'].includes(key)?'dock':'apps').append(b);
  }
  $('close').onclick=close; $('unlock').onclick=() => view('home');
  $('home-button').onclick=() => view('home');
  $('back').onclick=() => current==='comments' ? open('feed') : view('home');
  $('lock-alert').onclick=() => alertData && open(alertData.app || 'notifications');
  $('lock').addEventListener('pointerdown',e => { lockTouch=e.clientY; });
  $('lock').addEventListener('pointerup',e => { if(lockTouch!==null && lockTouch-e.clientY>45) view('home'); lockTouch=null; });
  document.addEventListener('keydown',e => { if(e.key==='Escape' && !$('phone').hidden) { e.preventDefault(); close(); } });
  clock(); setInterval(clock,15000);
  function wire() {
    cef=window.cef;
    if (!cef || typeof cef.on!=='function') return false;
    cef.on('phone:online',() => { clearTimeout(probeTimer); $('connection').textContent='GTASANVN'; });
    cef.on('phone:open',show); cef.on('phone:closed',hide);
    cef.on('phone:alert',setAlert); cef.on('phone:alertClear',() => { $('alert').hidden=true; });
    cef.on('phone:notice',note); cef.on('phone:error',msg => { posting=false; clearTimeout(postTimer); note(msg); });
    cef.on('phone:state',(number,bank,name) => {
      if (data.number && Number(number) !== data.number) {
        Object.assign(data,{contacts:[],history:[],vehicles:[],posts:[],comments:[],notifications:[],
          transactions:null,tutorial:-1,battery:null,account:'',job:null,cash:0,level:0,license:0,
          position:null,gps:[],stage:-1,peer:0});
        data.unreadMessages.clear();
        selectedThread=0; selectedPost=0; alertData=null;
        $('lock-alert').hidden=true;
        renderBadges();
      }
      Object.assign(data,{number:Number(number),bank:Number(bank),name:String(name)});
      if(['bank','profile','settings'].includes(current)) render();
      if(current==='home') renderToday();
    });
    cef.on('phone:profileData',(cash,level,battery,license) => {
      Object.assign(data,{cash,level,battery,license:asBool(license)}); if(current==='profile') render();
    });
    cef.on('phone:jobData',(main,side,eligible,seconds,active,paycheck) => {
      data.job={main,side,eligible:asBool(eligible),seconds,active:asBool(active),paycheck}; if(current==='jobs') render();
    });
    cef.on('phone:vehiclesClear',() => { data.vehicles=[]; });
    cef.on('phone:vehicleItem',(id,db,name,plate,fuel,driving,storage) => { data.vehicles.push({id,db,name,plate,fuel,driving:asBool(driving),storage:Number(storage)}); });
    cef.on('phone:vehiclesDone',() => { if(current==='vehicles') render(); });
    cef.on('phone:callState',(stage,peer) => { data.stage=Number(stage); data.peer=Number(peer); renderCallState(); renderBadges(); if(current==='home') renderToday(); });
    cef.on('phone:contactsClear',() => { data.contacts=[]; });
    cef.on('phone:contactItem',(id,name,number) => { data.contacts.push({id,name,number}); });
    cef.on('phone:contactsDone',() => refreshList('contact-list',renderContactItems));
    cef.on('phone:hubInfo',(stage,battery,silent,account) => {
      Object.assign(data,{tutorial:Number(stage),battery:Number(battery),silent:asBool(silent),account});
      if(current==='home') renderToday();
      if(['settings','missions','bank'].includes(current)) render();
    });
    cef.on('phone:messageReceived',sender => {
      const number=Number(sender);
      if (current !== 'sms' || selectedThread !== number)
        data.unreadMessages.set(number,(data.unreadMessages.get(number) || 0)+1);
      renderBadges();
    });
    cef.on('phone:gpsClear',(x,y) => { data.position={x:Number(x),y:Number(y)}; data.gps=[]; });
    cef.on('phone:gpsItem',(id,name,category,x,y,distance) => {
      data.gps.push({id,name,category,x:Number(x),y:Number(y),distance:Number(distance)});
    });
    cef.on('phone:gpsDone',() => { if(current==='map') updateGPS?.(); });
    cef.on('phone:bankClear',() => { data.transactions=[]; });
    cef.on('phone:bankItem',(kind,amount,date) => { data.transactions.push({kind,amount,date}); });
    cef.on('phone:bankDone',() => { if(current==='bank') render(); });
    cef.on('phone:historyClear',() => { data.history=[]; });
    cef.on('phone:historyItem',(id,from,to,text,position) => {
      data.history.push({id,from:Number(from),to:Number(to),text,position:asBool(position)});
    });
    cef.on('phone:messageSent',number => {
      const draft=$('sms-body');
      if(smsDraft && Number(number)===smsDraft.to && draft && draft.value.trim()===smsDraft.message) draft.value='';
      smsDraft=null;
      note('Đã gửi tin nhắn.');
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
    return true;
  }
  try { setPosition(localStorage.getItem('gtasanvn-phone-position') || 'center', false); } catch {}
  if (!wire() && !demo) {
    let attempts=0;
    const bridgeTimer=setInterval(() => { if(wire() || ++attempts===30) clearInterval(bridgeTimer); },250);
  }
  if (demo) {
    $('connection').textContent='Bản xem trước';
    Object.assign(data,{
      tutorial:1,battery:85,account:'LS-00002808',transactions:[{kind:'atm_deposit',amount:250,date:'2026-11-22 18:30:00'}],
      position:{x:1930,y:-1720},gps:[{id:0,name:'Pizza Stack',category:'Việc làm',x:2100,y:-1810,distance:192},{id:1,name:'City Hall',category:'Giấy tờ',x:1481,y:-1772,distance:452}],
      name:'Minh Nguyen',number:280821, bank:28950, cash:490, level:4,license:true,
      job:{main:'Giao pizza',side:'Không',eligible:true,seconds:38,active:true,paycheck:135},
      vehicles:[{id:8,db:20,name:'Premier',plate:'LS-2808',fuel:72,driving:true,storage:1}],
      history:[{id:8,from:280833,to:280821,text:'Đón mình ở Idlewood nhé.'},{id:9,from:280833,to:280821,position:true}],
      contacts:[{id:1,name:'Anh Vũ',number:280833}],
      posts:[{id:1,name:'Anh Vũ',body:'Tối nay gặp nhau ở Idlewood nhé.',photo:'',likes:3,liked:false}]
    });
    show(); setAlert('Pizza Stack','Có đơn giao mới.');
  }
})();
