/* قرمشة — الطبقة المشتركة: قاعدة البيانات (Firebase أو وضع المعاينة) + أدوات عامة */
(function(){
"use strict";
var CONF=window.QARMASHA_CONFIG||{};
var SEED={"settings": {"name": "قرمشة", "tagline": "برغر على الفحم، دجاج مقرمش، بيتزا وسندويشات. اطلب من طاولتك ويوصلك طازج.", "phone": "0770 123 4567", "address": "شارع المطاعم، بغداد", "hero": "photos/hero.jpg", "tables": 12, "servicePct": 0, "open": true, "openAt": "12:00", "closeAt": "02:00", "whatsapp": "9647701234567", "delivery": {"enabled": true, "minOrder": 10000, "areas": [{"name": "المنصور", "fee": 2000}, {"name": "اليرموك", "fee": 2000}, {"name": "الكرادة", "fee": 3000}, {"name": "زيونة", "fee": 3000}, {"name": "الأعظمية", "fee": 3500}, {"name": "الدورة", "fee": 4000}]}, "pickup": true, "valet": true}, "categories": [{"id": "burger", "name": "برغر"}, {"id": "chicken", "name": "دجاج"}, {"id": "pizza", "name": "بيتزا"}, {"id": "sandwich", "name": "سندويشات"}, {"id": "sides", "name": "مقبلات"}, {"id": "drinks", "name": "مشروبات"}, {"id": "dessert", "name": "حلويات"}], "items": {"i1": {"id": "i1", "cat": "burger", "name": "كلاسيك برغر", "desc": "لحم بقري 150غ على الفحم، شيدر، خس، طماطم، صوص قرمشة الخاص", "price": 7000, "discount": 0, "tags": ["best"], "available": true, "img": "photos/i1.jpg", "stock": null, "sort": 0}, "i2": {"id": "i2", "cat": "burger", "name": "دبل سماش", "desc": "قطعتين سماش، جبن مزدوج، بصل، مخلل", "price": 10000, "discount": 15, "tags": ["best"], "available": true, "img": "photos/i2.jpg", "stock": 6, "sort": 1}, "i3": {"id": "i3", "cat": "burger", "name": "برغر الجحيم", "desc": "لحم، هالبينو، بيبر جاك، صوص حار جداً", "price": 9000, "discount": 0, "tags": ["hot"], "available": true, "img": "photos/i3.jpg", "stock": null, "sort": 2}, "i4": {"id": "i4", "cat": "burger", "name": "ماشروم سويس", "desc": "لحم بقري، فطر سوتيه، جبن سويسري، مايونيز الثوم", "price": 9500, "discount": 0, "tags": ["new"], "available": true, "img": "photos/i4.jpg", "stock": null, "sort": 3}, "i5": {"id": "i5", "cat": "chicken", "name": "بوكس دجاج مقرمش", "desc": "4 قطع دجاج مقرمش مع بطاطا وصوص ثوم", "price": 11000, "discount": 0, "tags": ["best"], "available": true, "img": "photos/i5.jpg", "stock": null, "sort": 4}, "i6": {"id": "i6", "cat": "chicken", "name": "زنجر", "desc": "صدر دجاج حار مقرمش، خس، مايونيز، خبز بريوش", "price": 7500, "discount": 0, "tags": ["hot"], "available": true, "img": "photos/i6.jpg", "stock": null, "sort": 5}, "i7": {"id": "i7", "cat": "chicken", "name": "أجنحة بافلو", "desc": "8 أجنحة بصوص البافلو مع رانش", "price": 8500, "discount": 10, "tags": ["hot"], "available": true, "img": "photos/i7.jpg", "stock": 4, "sort": 6}, "i8": {"id": "i8", "cat": "chicken", "name": "ستربس دجاج", "desc": "6 أصابع دجاج مع صوص العسل والخردل", "price": 7000, "discount": 0, "tags": [], "available": true, "img": "photos/i8.jpg", "stock": null, "sort": 7}, "i9": {"id": "i9", "cat": "pizza", "name": "بيتزا مارغريتا", "desc": "صوص طماطم، موزاريلا، ريحان · وسط", "price": 8000, "discount": 0, "tags": [], "available": true, "img": "photos/i9.jpg", "stock": null, "sort": 8}, "i10": {"id": "i10", "cat": "pizza", "name": "بيتزا ببروني", "desc": "ببروني بقري، موزاريلا مضاعفة · وسط", "price": 10000, "discount": 0, "tags": ["best"], "available": true, "img": "photos/i10.jpg", "stock": null, "sort": 9}, "i11": {"id": "i11", "cat": "pizza", "name": "بيتزا دجاج باربكيو", "desc": "دجاج مشوي، بصل، صوص باربكيو · وسط", "price": 11000, "discount": 0, "tags": ["new"], "available": true, "img": "photos/i11.jpg", "stock": null, "sort": 10}, "i12": {"id": "i12", "cat": "sandwich", "name": "شاورما دجاج", "desc": "صاج، ثومية، مخلل، بطاطا", "price": 4000, "discount": 0, "tags": ["best"], "available": true, "img": "photos/i12.jpg", "stock": null, "sort": 11}, "i13": {"id": "i13", "cat": "sandwich", "name": "هوت دوغ", "desc": "نقانق بقري، خردل، كاتشب، بصل مقرمش", "price": 5000, "discount": 0, "tags": [], "available": true, "img": "photos/i13.jpg", "stock": null, "sort": 12}, "i14": {"id": "i14", "cat": "sandwich", "name": "فيلي ستيك", "desc": "شرائح لحم، فلفل، بصل، جبن ذايب", "price": 9000, "discount": 0, "tags": [], "available": true, "img": "photos/i14.jpg", "stock": 0, "sort": 13}, "i15": {"id": "i15", "cat": "sides", "name": "بطاطا مقلية", "desc": "مقرمشة مع ملح البحر · حجم كبير", "price": 3000, "discount": 0, "tags": ["best"], "available": true, "img": "photos/i15.jpg", "stock": null, "sort": 14}, "i16": {"id": "i16", "cat": "sides", "name": "بطاطا بالجبن", "desc": "صوص شيدر ذايب وهالبينو", "price": 4500, "discount": 0, "tags": [], "available": true, "img": "photos/i16.jpg", "stock": null, "sort": 15}, "i17": {"id": "i17", "cat": "sides", "name": "حلقات البصل", "desc": "10 حلقات مقرمشة مع صوص باربكيو", "price": 3500, "discount": 0, "tags": [], "available": true, "img": "photos/i17.jpg", "stock": null, "sort": 16}, "i18": {"id": "i18", "cat": "sides", "name": "سلطة كول سلو", "desc": "ملفوف، جزر، صوص كريمي", "price": 2000, "discount": 0, "tags": [], "available": true, "img": "photos/i18.jpg", "stock": null, "sort": 17}, "i19": {"id": "i19", "cat": "drinks", "name": "مشروب غازي", "desc": "بيبسي، سفن أب أو ميرندا", "price": 1000, "discount": 0, "tags": [], "available": true, "img": "photos/i19.jpg", "stock": null, "sort": 18}, "i20": {"id": "i20", "cat": "drinks", "name": "ميلك شيك", "desc": "فانيلا، شوكولاتة أو فراولة", "price": 4000, "discount": 0, "tags": ["new"], "available": true, "img": "photos/i20.jpg", "stock": null, "sort": 19}, "i21": {"id": "i21", "cat": "drinks", "name": "ليمون بالنعناع", "desc": "طازج ومثلج", "price": 2500, "discount": 0, "tags": [], "available": true, "img": "photos/i21.jpg", "stock": null, "sort": 20}, "i22": {"id": "i22", "cat": "dessert", "name": "دونات", "desc": "قطعتين، فراولة وشوكولاتة", "price": 3000, "discount": 0, "tags": [], "available": true, "img": "photos/i22.jpg", "stock": null, "sort": 21}, "i23": {"id": "i23", "cat": "dessert", "name": "آيس كريم صنداي", "desc": "فانيلا مع صوص كراميل ومكسرات", "price": 3500, "discount": 0, "tags": [], "available": true, "img": "photos/i23.jpg", "stock": null, "sort": 22}}, "offers": {"o1": {"id": "o1", "title": "وجبة العائلة", "desc": "4 برغر كلاسيك + 2 بطاطا كبيرة + 4 مشروبات", "price": 30000, "oldPrice": 38000, "active": true, "img": "photos/o1.jpg", "sort": 0}, "o2": {"id": "o2", "title": "عرض الطلاب", "desc": "زنجر + بطاطا + مشروب", "price": 9000, "oldPrice": 11500, "active": true, "img": "photos/o2.jpg", "sort": 1}, "o3": {"id": "o3", "title": "بيتزا 1+1", "desc": "اشترِ بيتزا ببروني وخذ مارغريتا مجاناً", "price": 10000, "oldPrice": 18000, "active": true, "img": "photos/o3.jpg", "sort": 2}}};

/* ---------------- helpers ---------------- */
var Q={};
Q.SEED=SEED;
Q.esc=function(s){return String(s==null?"":s).replace(/[&<>"']/g,function(c){return{"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c];});};
Q.money=function(n){return Math.round(+n||0).toLocaleString("en-US")+" د.ع";};
Q.isoDay=function(t){var d=new Date(t);return d.getFullYear()+"-"+String(d.getMonth()+1).padStart(2,"0")+"-"+String(d.getDate()).padStart(2,"0");};
Q.ago=function(t){var m=Math.floor((Date.now()-t)/60000);if(m<1)return"هسه";if(m<60)return"قبل "+m+" د";var h=Math.floor(m/60);if(h<24)return"قبل "+h+" س";return new Date(t).toLocaleDateString("ar-IQ");};
Q.mins=function(t){return Math.floor((Date.now()-t)/60000);};
Q.clock=function(t){return new Date(t).toLocaleTimeString("ar-IQ",{hour:"2-digit",minute:"2-digit"});};
Q.shortNo=function(){return 100+Math.floor(Date.now()/1000)%9900;};
Q.uid=function(p){return(p||"")+Date.now().toString(36)+Math.random().toString(36).slice(2,7);};
Q.unitPrice=function(it){return Math.round(it.price*(1-(+it.discount||0)/100)/250)*250;};
Q.avail=function(it){return!!it.available&&(it.stock==null||it.stock>0);};
Q.stars=function(n){n=Math.round(n||0);return"★★★★★".slice(0,n)+"☆☆☆☆☆".slice(0,5-n);};
Q.tagLabel=function(t){return{hot:"حار",new:"جديد",best:"الأكثر طلباً"}[t]||t;};
Q.objList=function(m){return Object.keys(m||{}).map(function(k){var v=m[k];return v?Object.assign({},v,{id:k}):null;}).filter(Boolean).sort(function(a,b){return(a.sort||0)-(b.sort||0);});};
Q.isOpen=function(s){if(!s||s.open===false)return false;function m(t){var p=String(t||"0:0").split(":");return(+p[0]||0)*60+(+p[1]||0);}var d=new Date(),n=d.getHours()*60+d.getMinutes(),a=m(s.openAt),b=m(s.closeAt);if(a===b)return true;return a<b?(n>=a&&n<b):(n>=a||n<b);};
Q.TYPE={dine:"بالمطعم",delivery:"توصيل",pickup:"استلام"};
Q.STATUS={pending:"بانتظار الموافقة",accepted:"انقبل الطلب",prep:"يتحضّر",ready:"جاهز",out:"بالطريق إليك",served:"وصل طاولتك",done:"تم",rejected:"انرفض"};
Q.CAR={requested:"بانتظار الكراج",coming:"سيارتك جاية",arrived:"سيارتك عند الباب",done:"تم التسليم"};

/* image cache: "fs:<id>" images live in the images collection */
var IMG={},imgWait={};
Q.imgSrc=function(src,onLoad){
  if(!src)return"";
  if(String(src).indexOf("fs:")!==0)return src;
  var id=src.slice(3);
  if(IMG[id])return IMG[id];
  if(!imgWait[id]){imgWait[id]=1;Q.db.get("images/"+id).then(function(d){if(d&&d.data){IMG[id]=d.data;onLoad&&onLoad();}}).catch(function(){});}
  return"";
};
Q.photo=function(src,alt,onLoad,cls){var a=String(alt||"").trim(),u=Q.imgSrc(src,onLoad);
  return'<div class="ph'+(cls?" "+cls:"")+'">'+(u?'<img src="'+Q.esc(u)+'" alt="'+Q.esc(a)+'" '+(cls==="eager"?'':'loading="lazy" ')+'decoding="async" onload="this.classList.add(\'ok\')" onerror="this.remove()">':'')+'<span class="fb" aria-hidden="true">'+Q.esc(a.charAt(0)||"؟")+'</span></div>';};
Q.shrink=function(file,max,q){return new Promise(function(res,rej){var url=URL.createObjectURL(file),im=new Image();
  im.onload=function(){var sc=Math.min(1,(max||640)/Math.max(im.width,im.height)),c=document.createElement("canvas");c.width=Math.round(im.width*sc);c.height=Math.round(im.height*sc);c.getContext("2d").drawImage(im,0,0,c.width,c.height);URL.revokeObjectURL(url);res(c.toDataURL("image/jpeg",q||.78));};
  im.onerror=function(){URL.revokeObjectURL(url);rej(new Error("bad image"));};im.src=url;});};

/* sound */
var actx=null;
document.addEventListener("pointerdown",function(){if(!actx){try{actx=new(window.AudioContext||window.webkitAudioContext)();}catch(e){}}});
Q.beep=function(times){if(!actx)return;times=times||1;for(var i=0;i<times;i++)(function(i){setTimeout(function(){try{var o=actx.createOscillator(),g=actx.createGain();o.type="sine";o.frequency.value=i%2?660:880;g.gain.setValueAtTime(.0001,actx.currentTime);g.gain.exponentialRampToValueAtTime(.3,actx.currentTime+.02);g.gain.exponentialRampToValueAtTime(.0001,actx.currentTime+.35);o.connect(g);g.connect(actx.destination);o.start();o.stop(actx.currentTime+.4);}catch(e){}},i*380);})(i);};

/* toasts */
Q.toast=function(m,kind){var box=document.getElementById("toasts");if(!box){box=document.createElement("div");box.id="toasts";box.className="toasts";box.setAttribute("role","status");document.body.appendChild(box);}
  if(box.lastChild&&box.lastChild.textContent===m)return;while(box.children.length>=3)box.firstChild.remove();
  var d=document.createElement("div");d.className="toast"+(kind?" "+kind:"");d.textContent=m;box.appendChild(d);setTimeout(function(){d.classList.add("out");setTimeout(function(){d.remove();},300);},4000);};

/* ---------------- database adapters ---------------- */
function splitPath(p){return p.split("/");}
function localDB(){
  var KEY="qarmasha-preview-db",subs=[];
  function load(){try{return JSON.parse(localStorage.getItem(KEY)||"{}");}catch(e){return{};}}
  var store=load();
  if(!store["menu/config"]&&SEED){store["menu/config"]=JSON.parse(JSON.stringify(SEED));try{localStorage.setItem(KEY,JSON.stringify(store));}catch(e){}}
  function save(){try{localStorage.setItem(KEY,JSON.stringify(store));}catch(e){Q.toast("مساحة المتصفح امتلأت");}}
  function fire(){subs.slice().forEach(function(s){s();});}
  window.addEventListener("storage",function(e){if(e.key===KEY){store=load();fire();}});
  function changed(){save();setTimeout(fire,0);}
  function inColl(path,coll){var p=splitPath(path);return p.length===splitPath(coll).length+1&&p.slice(0,-1).join("/")===coll;}
  function clone(x){return x==null?x:JSON.parse(JSON.stringify(x));}
  function test(v,op,w){switch(op){case"==":return v===w;case"!=":return v!==w;case">=":return v>=w;case"<=":return v<=w;case">":return v>w;case"<":return v<w;case"in":return w.indexOf(v)>-1;}return true;}
  function run(coll,where){return Object.keys(store).filter(function(p){return inColl(p,coll);}).map(function(p){return Object.assign(clone(store[p]),{id:p.split("/").pop()});}).filter(function(d){return(where||[]).every(function(w){return test(d[w[0]],w[1],w[2]);});});}
  function setDot(o,path,v){var p=path.split("."),c=o;for(var i=0;i<p.length-1;i++){if(c[p[i]]==null||typeof c[p[i]]!=="object")c[p[i]]={};c=c[p[i]];}if(v===Q.DELETE)delete c[p[p.length-1]];else c[p[p.length-1]]=clone(v);}
  return{
    mode:"local",
    onDoc:function(path,cb){var s=function(){cb(store[path]?clone(store[path]):null);};subs.push(s);setTimeout(s,0);return function(){subs.splice(subs.indexOf(s),1);};},
    onQuery:function(coll,where,cb){var s=function(){cb(run(coll,where));};subs.push(s);setTimeout(s,0);return function(){subs.splice(subs.indexOf(s),1);};},
    get:function(path){return Promise.resolve(store[path]?clone(store[path]):null);},
    query:function(coll,where){return Promise.resolve(run(coll,where));},
    add:function(coll,data){var id=Q.uid();store[coll+"/"+id]=clone(data);changed();return Promise.resolve(id);},
    set:function(path,data){store[path]=clone(data);changed();return Promise.resolve();},
    update:function(path,data){if(!store[path])return Promise.reject(new Error("not-found"));Object.keys(data).forEach(function(k){setDot(store[path],k,data[k]);});changed();return Promise.resolve();},
    del:function(path){delete store[path];changed();return Promise.resolve();},
    auth:{current:{email:CONF.ownerEmail||"preview@qarmasha",preview:true},onChange:function(cb){setTimeout(function(){cb({email:CONF.ownerEmail||"preview@qarmasha",preview:true});},0);},signIn:function(){return Promise.resolve();},signOut:function(){return Promise.resolve();}},
    reset:function(){localStorage.removeItem(KEY);location.reload();}
  };
}
function fireDB(){
  var app=firebase.initializeApp(CONF.firebase),fs=firebase.firestore(),au=firebase.auth();
  try{fs.enablePersistence({synchronizeTabs:true}).catch(function(){});}catch(e){}
  function ref(path){return fs.doc(path);}
  function q(coll,where){var r=fs.collection(coll);(where||[]).forEach(function(w){r=r.where(w[0],w[1],w[2]);});return r;}
  function list(s){return s.docs.map(function(d){return Object.assign(d.data(),{id:d.id});});}
  function fix(data){var o={};Object.keys(data).forEach(function(k){o[k]=data[k]===Q.DELETE?firebase.firestore.FieldValue.delete():data[k];});return o;}
  return{
    mode:"firebase",
    onDoc:function(path,cb,err){return ref(path).onSnapshot(function(s){cb(s.exists?s.data():null);},function(e){err&&err(e);console.warn(e);});},
    onQuery:function(coll,where,cb,err){return q(coll,where).onSnapshot(function(s){cb(list(s));},function(e){err&&err(e);console.warn(e);});},
    get:function(path){return ref(path).get().then(function(s){return s.exists?s.data():null;});},
    query:function(coll,where){return q(coll,where).get().then(list);},
    add:function(coll,data){return fs.collection(coll).add(data).then(function(r){return r.id;});},
    set:function(path,data){return ref(path).set(data);},
    update:function(path,data){return ref(path).update(fix(data));},
    del:function(path){return ref(path).delete();},
    auth:{get current(){return au.currentUser;},onChange:function(cb){au.onAuthStateChanged(cb);},signIn:function(e,p){return au.signInWithEmailAndPassword(e,p);},signOut:function(){return au.signOut();}}
  };
}
Q.DELETE={__delete:true};
Q.live=!!(CONF.firebase&&window.firebase);
Q.db=Q.live?fireDB():localDB();
Q.ownerEmail=String(CONF.ownerEmail||"").trim().toLowerCase();
Q.isOwner=function(user){if(!user)return false;if(user.preview)return true;return!!Q.ownerEmail&&String(user.email||"").toLowerCase()===Q.ownerEmail;};
Q.errMsg=function(e){var c=e&&(e.code||e.message)||"";
  if(/permission/i.test(c))return"ما عندك صلاحية لهذا الإجراء.";
  if(/unavailable|network/i.test(c))return"ماكو اتصال بالإنترنت. تأكد وجرّب مرة ثانية.";
  if(/wrong-password|invalid-credential|user-not-found|invalid-login/i.test(c))return"الإيميل أو الرمز غلط.";
  if(/too-many/i.test(c))return"محاولات كثيرة، انتظر شوية وجرّب.";
  return"ما گدرنا نكمل، جرّب مرة ثانية.";};

/* menu config helpers */
Q.parseMenu=function(d){d=d||{};var s=Object.assign({name:"قرمشة",tables:12,delivery:{enabled:false,areas:[],minOrder:0}},d.settings||{});s.delivery=Object.assign({enabled:false,areas:[],minOrder:0},s.delivery||{});
  return{settings:s,categories:(d.categories||[]).slice(),items:Q.objList(d.items),offers:Q.objList(d.offers)};};

window.Q=Q;
})();
