import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import {z} from 'zod';
import {randomUUID} from 'node:crypto';
import {hash,otp,opaque,publicUser} from './security.js';

const vietnamDateTime = (date=new Date()) => {
 const parts=new Intl.DateTimeFormat('en-GB',{timeZone:'Asia/Ho_Chi_Minh',year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(date);
 const values=Object.fromEntries(parts.map(({type,value})=>[type,value]));
 return {day:`${values.year}-${values.month}-${values.day}`,time:`${values.hour}:${values.minute}`};
};

export function createApp({pool,sendMail,env=process.env}) {
 const app=express();
 app.set('trust proxy',1); app.use(helmet());
 app.use(cors({origin:env.ALLOWED_ORIGIN?.split(',') || false}));
 app.use(express.json({limit:'32kb'}));
 const run=(fn)=>(req,res,next)=>Promise.resolve(fn(req,res)).catch(next);
 const q=(sql,args=[])=>pool.query(sql,args);
 const fail=(status,message)=>{const e=new Error(message);e.status=status;throw e;};
 const auth=run(async(req,res)=>{
  try {const p=jwt.verify(req.headers.authorization?.replace(/^Bearer /,''),env.JWT_SECRET,{algorithms:['HS256'],issuer:'childguard',audience:'childguard-mobile'});const r=await q('SELECT * FROM users WHERE id=$1',[p.sub]); if(!r.rows[0]) fail(401,'Phiên hết hạn');req.user=r.rows[0];}catch {fail(401,'Vui lòng đăng nhập lại');}
 });
 // Express middleware must call next explicitly after resolving authentication.
 const authenticated=(req,res,next)=>auth(req,res,err=>next(err))?.then(()=>{if(req.user)next();});
 const roles=(...allowed)=>(req,res,next)=>allowed.includes(req.user.role)?next():res.status(403).json({message:'Không đủ quyền'});
 const token=u=>jwt.sign({role:u.role},env.JWT_SECRET,{subject:u.id,expiresIn:'12h',issuer:'childguard',audience:'childguard-mobile'});
 const session=u=>({token:token(u),user:publicUser(u)});
 const owned=async(id,u)=>{const r=await q('SELECT c.* FROM children c LEFT JOIN child_links l ON l.child_id=c.id WHERE c.id=$1 AND (c.parent_id=$2 OR l.user_id=$2)',[id,u.id]);return r.rows[0] || fail(404,'Không tìm thấy hồ sơ');};
 const parentOwned=async(id,u)=>{const c=await owned(id,u);if(c.parent_id!==u.id)fail(403,'Chỉ phụ huynh được thay đổi');return c;};
 const idSchema=z.string().uuid();
 const challenge=async(u,kind)=>{const code=otp(),id=randomUUID();await q('DELETE FROM challenges WHERE user_id=$1 AND kind=$2',[u.id,kind]);await q("INSERT INTO challenges(id,user_id,kind,digest,expires_at) VALUES($1,$2,$3,$4,now()+interval '5 minutes')",[id,u.id,kind,hash(code)]);await sendMail(u.email,code,kind);return {challengeId:id,message:'Mã OTP đã gửi đến email, có hiệu lực 5 phút'};};
 app.get('/health',run(async(req,res)=>{await q('SELECT 1');res.json({status:'ok'});}));
 app.use('/auth',rateLimit({windowMs:15*60*1000,limit:30,standardHeaders:'draft-7',legacyHeaders:false}));
 app.post('/auth/register',run(async(req,res)=>{
  const b=z.object({email:z.string().email().max(254),username:z.string().regex(/^[a-zA-Z0-9_]{3,32}$/),name:z.string().trim().min(2).max(80),password:z.string().min(10).max(72)}).parse(req.body);
  const u={...b,id:randomUUID()};
  await q('INSERT INTO users(id,email,username,name,password) VALUES($1,$2,$3,$4,$5)',[u.id,b.email.toLowerCase(),b.username.toLowerCase(),b.name,await bcrypt.hash(b.password,12)]);
  res.status(201).json(await challenge(u,'verify'));
 }));
 app.post('/auth/login',run(async(req,res)=>{
  const b=z.object({username:z.string().max(254),password:z.string().max(72)}).parse(req.body);
  const {rows}=await q('SELECT * FROM users WHERE username=$1 OR email=$1',[b.username.toLowerCase()]);const u=rows[0];
  if(!u?.password || !await bcrypt.compare(b.password,u.password))fail(401,'Thông tin đăng nhập không đúng');
  res.json({...await challenge(u,u.verified?'login':'verify'),kind:u.verified?'login':'verify'});
 }));
 app.post('/auth/otp',run(async(req,res)=>{
  const b=z.object({challengeId:z.string().uuid(),code:z.string().regex(/^\d{6}$/)}).parse(req.body);
  const c=await pool.connect(); let u;
    try {await c.query('BEGIN');const {rows}=await c.query("SELECT * FROM challenges WHERE id=$1 AND kind IN ('login','verify','email-change') FOR UPDATE",[b.challengeId]);const ch=rows[0];
   if(!ch || new Date(ch.expires_at)<new Date() || ch.attempts>=5)fail(401,'OTP hết hạn hoặc bị khóa');
   if(ch.digest!==hash(b.code)){await c.query('UPDATE challenges SET attempts=attempts+1 WHERE id=$1',[ch.id]);await c.query('COMMIT');fail(401,'OTP không đúng');}
    await c.query('DELETE FROM challenges WHERE id=$1',[ch.id]);u=ch.kind==='email-change'
     ?(await c.query('UPDATE users SET email=$2,verified=true WHERE id=$1 RETURNING *',[ch.user_id,ch.payload.email])).rows[0]
     :(await c.query('UPDATE users SET verified=true WHERE id=$1 RETURNING *',[ch.user_id])).rows[0];await c.query('COMMIT');
  }catch(e){await c.query('ROLLBACK');throw e;}finally{c.release();}res.json(session(u));
 }));
 app.get('/auth/google/start',run(async(req,res)=>{
  if(!env.GOOGLE_CLIENT_ID||!env.GOOGLE_CLIENT_SECRET)fail(503,'Google OAuth chưa được cấu hình');
  const verifierHash=z.string().regex(/^[a-f0-9]{64}$/).parse(req.query.verifierHash);const state=opaque();
  await q("INSERT INTO challenges(id,kind,digest,expires_at,payload) VALUES($1,'oauth-state',$2,now()+interval '5 minutes',$3)",[randomUUID(),hash(state),JSON.stringify({verifierHash})]);
  const url=new URL('https://accounts.google.com/o/oauth2/v2/auth');url.search=new URLSearchParams({client_id:env.GOOGLE_CLIENT_ID,redirect_uri:env.PUBLIC_URL+'/auth/google/callback',response_type:'code',scope:'openid email profile',state}).toString();res.redirect(url.href);
 }));
 app.get('/auth/google/callback',run(async(req,res)=>{
  const state=z.string().parse(req.query.state);const ch=(await q("DELETE FROM challenges WHERE digest=$1 AND kind='oauth-state' AND expires_at>now() RETURNING *",[hash(state)])).rows[0];if(!ch)fail(401,'OAuth state không hợp lệ');
  const r=await fetch('https://oauth2.googleapis.com/token',{method:'POST',body:new URLSearchParams({code:z.string().parse(req.query.code),client_id:env.GOOGLE_CLIENT_ID,client_secret:env.GOOGLE_CLIENT_SECRET,redirect_uri:env.PUBLIC_URL+'/auth/google/callback',grant_type:'authorization_code'})});const t=await r.json();if(!r.ok)fail(401,'Google từ chối đăng nhập');
  const info=await fetch('https://openidconnect.googleapis.com/v1/userinfo',{headers:{Authorization:`Bearer ${t.access_token}`}});const g=await info.json();if(!info.ok||!g.email_verified)fail(401,'Email Google chưa xác minh');
  const email=z.string().email().parse(g.email).toLowerCase();let u=(await q('SELECT * FROM users WHERE email=$1',[email])).rows[0];
  if(!u)u=(await q('INSERT INTO users(id,email,username,name,verified) VALUES($1,$2,$3,$4,true) RETURNING *',[randomUUID(),email,'g_'+randomUUID().replaceAll('-',''),g.name||email])).rows[0];
  // Existing password accounts must verify their normal email OTP before account linking.
  // Exchange requires email OTP for existing password accounts; never issue a session directly.
  const code=opaque();await q("INSERT INTO challenges(id,user_id,kind,digest,expires_at,payload) VALUES($1,$2,'oauth-exchange',$3,now()+interval '1 minute',$4)",[randomUUID(),u.id,hash(code),JSON.stringify(ch.payload)]);res.redirect('childguard://auth?code='+code);
 }));
 app.post('/auth/google/exchange',run(async(req,res)=>{
  const b=z.object({code:z.string().min(20).max(100),verifier:z.string().min(32).max(100)}).parse(req.body);
  const ch=(await q("DELETE FROM challenges WHERE digest=$1 AND kind='oauth-exchange' AND payload->>'verifierHash'=$2 AND expires_at>now() RETURNING *",[hash(b.code),hash(b.verifier)])).rows[0];if(!ch)fail(401,'Mã OAuth không hợp lệ');const u=(await q('SELECT * FROM users WHERE id=$1',[ch.user_id])).rows[0];if(!u)fail(401,'Tài khoản không còn tồn tại');if(u.password){res.json({...await challenge(u,'login'),requiresOtp:true});return;}res.json(session(u));
 }));
 app.use(authenticated);
 app.get('/me',(req,res)=>res.json(publicUser(req.user)));
 app.patch('/me',run(async(req,res)=>{
  const b=z.object({name:z.string().trim().min(2).max(80)}).strict().parse(req.body);
  const u=(await q('UPDATE users SET name=$2 WHERE id=$1 RETURNING *',[req.user.id,b.name])).rows[0];res.json(publicUser(u));
 }));
 app.post('/me/email',run(async(req,res)=>{
  const email=z.string().email().max(254).parse(req.body.email).toLowerCase();
  if(email===req.user.email)return res.json({message:'Email không thay đổi'});
  const existing=(await q('SELECT id FROM users WHERE email=$1',[email])).rows[0];if(existing)fail(409,'Email đã được sử dụng');
  const id=randomUUID(),code=otp();await q("DELETE FROM challenges WHERE user_id=$1 AND kind='email-change'",[req.user.id]);
  await q("INSERT INTO challenges(id,user_id,kind,digest,expires_at,payload) VALUES($1,$2,'email-change',$3,now()+interval '5 minutes',$4)",[id,req.user.id,hash(code),JSON.stringify({email})]);
  await sendMail(email,code,'email-change');res.json({challengeId:id,message:'Mã OTP đã gửi đến email mới'});
 }));
 app.get('/children',run(async(req,res)=>{const {day}=vietnamDateTime();res.json((await q('SELECT c.*,COALESCE(r.minutes,0) AS bonus_minutes_today FROM children c LEFT JOIN child_links l ON l.child_id=c.id LEFT JOIN nfc_rewards r ON r.child_id=c.id AND r.reward_day=$2 WHERE c.parent_id=$1 OR l.user_id=$1 ORDER BY c.created_at DESC',[req.user.id,day])).rows);}));
 app.get('/children/:id/time-budget',run(async(req,res)=>{
  const id=idSchema.parse(req.params.id);await owned(id,req.user);const {day}=vietnamDateTime();
  const c=(await q('SELECT c.daily_limit,c.nfc_start_time,c.nfc_end_time,COALESCE(r.minutes,0) AS bonus_minutes_today FROM children c LEFT JOIN nfc_rewards r ON r.child_id=c.id AND r.reward_day=$2 WHERE c.id=$1',[id,day])).rows[0];
  const bonusMinutesToday=Number(c.bonus_minutes_today);
  res.json({...c,bonus_minutes_today:bonusMinutesToday,effective_daily_limit:c.daily_limit+bonusMinutesToday});
 }));
 const childBody=z.object({name:z.string().trim().min(1).max(80),age:z.number().int().min(1).max(17),daily_limit:z.number().int().min(15).max(1440)});
 app.post('/children',roles('parent'),run(async(req,res)=>{const b=childBody.parse(req.body);res.status(201).json((await q('INSERT INTO children(id,parent_id,name,age,daily_limit) VALUES($1,$2,$3,$4,$5) RETURNING *',[randomUUID(),req.user.id,b.name,b.age,b.daily_limit])).rows[0]);}));
 app.put('/children/:id',roles('parent'),run(async(req,res)=>{const id=idSchema.parse(req.params.id);await parentOwned(id,req.user);const b=childBody.parse(req.body);res.json((await q('UPDATE children SET name=$2,age=$3,daily_limit=$4 WHERE id=$1 RETURNING *',[id,b.name,b.age,b.daily_limit])).rows[0]);}));
 app.delete('/children/:id',roles('parent'),run(async(req,res)=>{await parentOwned(idSchema.parse(req.params.id),req.user);await q('DELETE FROM children WHERE id=$1',[req.params.id]);res.status(204).end();}));
 app.post('/children/:id/link',roles('parent'),run(async(req,res)=>{
  await parentOwned(idSchema.parse(req.params.id),req.user);const email=z.string().email().parse(req.body.email).toLowerCase();const u=(await q("SELECT * FROM users WHERE email=$1 AND role='child' AND verified=true",[email])).rows[0];if(!u)fail(404,'Không tìm thấy tài khoản trẻ đã xác minh');await q('INSERT INTO child_links(user_id,child_id) VALUES($1,$2) ON CONFLICT(child_id) DO UPDATE SET user_id=$1',[u.id,req.params.id]);res.json({message:'Đã liên kết tài khoản trẻ'});
 }));
 app.get('/children/:id/devices',run(async(req,res)=>{await owned(idSchema.parse(req.params.id),req.user);res.json((await q('SELECT * FROM devices WHERE child_id=$1 ORDER BY created_at DESC',[req.params.id])).rows);}));
 app.post('/children/:id/devices',roles('parent'),run(async(req,res)=>{await parentOwned(idSchema.parse(req.params.id),req.user);const name=z.string().trim().min(1).max(80).parse(req.body.name);res.status(201).json((await q('INSERT INTO devices(id,child_id,name) VALUES($1,$2,$3) RETURNING *',[randomUUID(),req.params.id,name])).rows[0]);}));
 app.put('/devices/:id',roles('parent'),run(async(req,res)=>{const d=(await q('SELECT * FROM devices WHERE id=$1',[idSchema.parse(req.params.id)])).rows[0];if(!d)fail(404,'Không tìm thấy thiết bị');await parentOwned(d.child_id,req.user);const name=z.string().trim().min(1).max(80).parse(req.body.name);res.json((await q('UPDATE devices SET name=$2 WHERE id=$1 RETURNING *',[d.id,name])).rows[0]);}));
 app.delete('/devices/:id',roles('parent'),run(async(req,res)=>{const d=(await q('SELECT * FROM devices WHERE id=$1',[idSchema.parse(req.params.id)])).rows[0];if(!d)fail(404,'Không tìm thấy thiết bị');await parentOwned(d.child_id,req.user);await q('DELETE FROM devices WHERE id=$1',[d.id]);res.status(204).end();}));
 app.get('/children/:id/agreements',run(async(req,res)=>{await owned(idSchema.parse(req.params.id),req.user);res.json((await q('SELECT * FROM agreements WHERE child_id=$1 ORDER BY created_at DESC',[req.params.id])).rows);}));
 app.post('/children/:id/agreements',roles('parent','child'),run(async(req,res)=>{await owned(idSchema.parse(req.params.id),req.user);const b=z.object({title:z.string().trim().min(3).max(200),reward:z.number().int().min(1).max(120)}).parse(req.body);res.status(201).json((await q('INSERT INTO agreements(id,child_id,title,reward) VALUES($1,$2,$3,$4) RETURNING *',[randomUUID(),req.params.id,b.title,b.reward])).rows[0]);}));
 app.patch('/agreements/:id',roles('parent'),run(async(req,res)=>{const a=(await q('SELECT * FROM agreements WHERE id=$1',[idSchema.parse(req.params.id)])).rows[0];if(!a)fail(404,'Không tìm thấy thỏa thuận');await parentOwned(a.child_id,req.user);const status=z.enum(['approved','rejected']).parse(req.body.status);res.json((await q('UPDATE agreements SET status=$2 WHERE id=$1 RETURNING *',[a.id,status])).rows[0]);}));
 app.delete('/agreements/:id',roles('parent'),run(async(req,res)=>{const a=(await q('SELECT * FROM agreements WHERE id=$1',[idSchema.parse(req.params.id)])).rows[0];if(!a)fail(404,'Không tìm thấy thỏa thuận');await parentOwned(a.child_id,req.user);await q('DELETE FROM agreements WHERE id=$1',[a.id]);res.status(204).end();}));
 app.put('/children/:id/nfc',roles('parent'),run(async(req,res)=>{await parentOwned(idSchema.parse(req.params.id),req.user);const tag=z.string().regex(/^[a-f0-9]{64}$/).parse(req.body.tagHash);await q('UPDATE children SET nfc_hash=$2 WHERE id=$1',[req.params.id,tag]);res.json({message:'Đã gắn thẻ NFC'});}));
 app.put('/children/:id/nfc-schedule',roles('parent'),run(async(req,res)=>{
  const id=idSchema.parse(req.params.id);await parentOwned(id,req.user);
  const b=z.object({startTime:z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/),endTime:z.string().regex(/^(?:[01]\d|2[0-3]):[0-5]\d$/)}).parse(req.body);
  if(b.startTime>=b.endTime)fail(400,'Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày');
  res.json((await q('UPDATE children SET nfc_start_time=$2,nfc_end_time=$3 WHERE id=$1 RETURNING nfc_start_time,nfc_end_time',[id,b.startTime,b.endTime])).rows[0]);
 }));
 app.post('/children/:id/checkins',roles('parent','child'),run(async(req,res)=>{
  const id=idSchema.parse(req.params.id);const scannedTag=z.string().regex(/^[a-f0-9]{64}$/).parse(req.body.tagHash);
  await owned(id,req.user);const {day,time}=vietnamDateTime();const client=await pool.connect();let result;
  try{
   await client.query('BEGIN');
   const child=(await client.query('SELECT nfc_hash,nfc_start_time,nfc_end_time,daily_limit FROM children WHERE id=$1 FOR UPDATE',[id])).rows[0];
   if(!child?.nfc_hash||child.nfc_hash!==scannedTag)fail(403,'Thẻ NFC không khớp');
   if(time<child.nfc_start_time||time>=child.nfc_end_time)fail(403,`Chỉ nhận thưởng từ ${child.nfc_start_time} đến trước ${child.nfc_end_time} (giờ Việt Nam).`);
   const checkin=(await client.query('INSERT INTO checkins(id,child_id) VALUES($1,$2) RETURNING *',[randomUUID(),id])).rows[0];
   const existingReward=(await client.query('SELECT minutes FROM nfc_rewards WHERE child_id=$1 AND reward_day=$2',[id,day])).rows[0];
   let awardedMinutes=0;
   if(!existingReward){
    const reward=(await client.query('INSERT INTO nfc_rewards(id,child_id,checkin_id,reward_day,minutes) VALUES($1,$2,$3,$4,30) RETURNING minutes',[randomUUID(),id,checkin.id,day])).rows[0];
    awardedMinutes=reward.minutes;
   }
   const bonusMinutesToday=existingReward?.minutes??30;
   result={...checkin,awarded_minutes:awardedMinutes,bonus_minutes_today:bonusMinutesToday,effective_daily_limit:child.daily_limit+bonusMinutesToday};
   await client.query('COMMIT');
  }catch(e){await client.query('ROLLBACK');throw e;}finally{client.release();}
  res.status(201).json(result);
 }));
 app.get('/children/:id/checkins',run(async(req,res)=>{await owned(idSchema.parse(req.params.id),req.user);res.json((await q('SELECT c.*,COALESCE(r.minutes,0) AS reward_minutes FROM checkins c LEFT JOIN nfc_rewards r ON r.checkin_id=c.id WHERE c.child_id=$1 ORDER BY c.created_at DESC LIMIT 50',[req.params.id])).rows);}));
 app.get('/children/:id/location',run(async(req,res)=>{
  await owned(idSchema.parse(req.params.id),req.user);
  const location=(await q('SELECT * FROM shared_locations WHERE child_id=$1',[req.params.id])).rows[0];
  res.json(location || null);
 }));
 const linkedChild=async(id,u)=>{
  if(u.role!=='child')fail(403,'Chỉ tài khoản trẻ được chia sẻ vị trí của mình');
  const link=(await q('SELECT * FROM child_links WHERE child_id=$1 AND user_id=$2',[id,u.id])).rows[0];
  if(!link)fail(404,'Không tìm thấy liên kết');
 };
 app.put('/children/:id/location',run(async(req,res)=>{
  const id=idSchema.parse(req.params.id);await linkedChild(id,req.user);
  const b=z.object({latitude:z.number().min(-90).max(90),longitude:z.number().min(-180).max(180),accuracy:z.number().min(0).max(100000)}).parse(req.body);
  res.json((await q('INSERT INTO shared_locations(child_id,latitude,longitude,accuracy) VALUES($1,$2,$3,$4) ON CONFLICT(child_id) DO UPDATE SET latitude=$2,longitude=$3,accuracy=$4,updated_at=now() RETURNING *',[id,b.latitude,b.longitude,b.accuracy])).rows[0]);
 }));
 app.delete('/children/:id/location',run(async(req,res)=>{
  const id=idSchema.parse(req.params.id);await linkedChild(id,req.user);
  await q('DELETE FROM shared_locations WHERE child_id=$1',[id]);res.status(204).end();
 }));
 app.get('/staff/dashboard',roles('staff','admin'),run(async(req,res)=>res.json((await q('SELECT (SELECT count(*) FROM users) AS users,(SELECT count(*) FROM children) AS children,(SELECT count(*) FROM devices) AS devices')).rows[0])));
 app.get('/admin/users',roles('admin'),run(async(req,res)=>res.json((await q('SELECT id,email,username,name,role,verified FROM users ORDER BY created_at DESC LIMIT 200')).rows)));
 app.patch('/admin/users/:id/role',roles('admin'),run(async(req,res)=>{const id=idSchema.parse(req.params.id);const role=z.enum(['parent','child','staff']).parse(req.body.role);if(id===req.user.id)fail(400,'Không thể đổi quyền chính mình');const u=(await q("UPDATE users SET role=$2 WHERE id=$1 AND role<>'admin' RETURNING *",[id,role])).rows[0];if(!u)fail(404,'Không tìm thấy hoặc không được đổi quyền quản trị');res.json(publicUser(u));}));
 app.use((req,res)=>res.status(404).json({message:'API không tồn tại'}));
 app.use((e,req,res,next)=>{if(e instanceof z.ZodError)return res.status(400).json({message:'Dữ liệu không hợp lệ',errors:e.flatten()});if(e.code==='23505')return res.status(409).json({message:'Email, tên tài khoản hoặc thẻ đã được sử dụng'});if(e.status)return res.status(e.status).json({message:e.message});console.error(e);res.status(500).json({message:'Lỗi máy chủ, vui lòng thử lại'});});
 return app;
}
