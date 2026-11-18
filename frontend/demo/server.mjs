import { existsSync, readFileSync, mkdirSync, writeFileSync, renameSync } from 'node:fs'
import { resolve } from 'node:path'
import { randomUUID } from 'node:crypto'

const money = cents => (cents / 100).toFixed(2)
export function seed() {
  const partners = ['云杉办公用品（演示）','星河软件服务（演示）','远山商务服务（演示）','青禾信息技术（演示）','北辰设备租赁（演示）','原野物流服务（演示）']
  const statuses = ['pending_posting','posted','verified','collected','pending_posting','verify_failed']
  const invoices = Array.from({length:36}, (_,i) => {
    const cents = 120000 + i * 32000, tax = Math.round(cents * 6 / 100)
    const row = {id:`inv-${i+1}`, tenant_id:i < 30 ? 'demo-a':'demo-b', number:`DEMO-202611-${String(i+1).padStart(4,'0')}`, kind:'数电专票', direction:i%4 ? '进项':'销项', partner:partners[i%6], date:`2026-11-${String(i%14+1).padStart(2,'0')}`, amount:money(cents), tax:money(tax), total:money(cents+tax), status:statuses[i%6], item:'技术服务费（演示）', voucher_id:'', suggestion:null, history:['模拟采集完成']}
    if (row.status === 'pending_posting') row.suggestion = suggestion(row)
    if (row.status === 'verify_failed') row.history.push('模拟异常：购方名称需人工核对')
    if (row.status === 'posted') {row.voucher_id=`v-${row.id}`; row.history.push('演示凭证已生成')}
    return row
  })
  return {invoices, risks:[
    {id:'risk-1',tenant_id:'demo-a',title:'票面信息不一致',severity:'高',invoice_id:'inv-6',owner:'',status:'open',description:'样例票据购方名称与当前主体不一致，请核对原票与主体信息。此提示仅为演示。',history:[]},
    {id:'risk-2',tenant_id:'demo-a',title:'入账建议需人工复核',severity:'中',invoice_id:'inv-5',owner:'财务专员',status:'assigned',description:'历史匹配样本不足，建议核实业务用途与科目。',history:['已指派给财务专员']},
    {id:'risk-3',tenant_id:'demo-b',title:'凭证附件待补充',severity:'低',invoice_id:'inv-31',owner:'',status:'open',description:'请检查附件完整性。',history:[]}
  ], idempotency:{}}
}
function suggestion(row) {
  const low = Number(row.id.replace('inv-','')) % 2 === 1 && row.id !== 'inv-1'
  return {id:`s-${row.id}`,account:row.direction==='销项'?'6001 主营业务收入':'6602 管理费用 / 技术服务费',confidence:low?0.86:0.96,need_review:low,
    reason:'固定演示规则：按票面服务内容匹配科目；实际科目及置信度应由后端规则引擎返回。',
    signals:[{name:'规则命中率',weight:'50%',value:low?'80%':'100%',source:low?'4 / 5 条演示规则命中':'5 / 5 条演示规则命中'}, {name:'历史一致性',weight:'30%',value:low?'90%':'90%',source:'9 / 10 条固定历史样本一致'}, {name:'字段完整度',weight:'20%',value:'95%',source:'19 / 20 个演示字段完整'}]}
}
function voucher(row) {
  const input = row.direction === '进项'
  return {id:row.voucher_id,number:`记 DEMO-${row.id.slice(4).padStart(4,'0')}`,period:row.date.slice(0,7),summary:`${row.partner} · ${row.item}`,debit_total:row.total,credit_total:row.total,
    lines:input ? [{account:'6602 管理费用 / 技术服务费',debit:row.amount,credit:'0.00'}, {account:'2221 应交税费 / 进项税额',debit:row.tax,credit:'0.00'}, {account:'2202 应付账款',debit:'0.00',credit:row.total}] : [{account:'1122 应收账款',debit:row.total,credit:'0.00'}, {account:'6001 主营业务收入',debit:'0.00',credit:row.amount}, {account:'2221 应交税费 / 销项税额',debit:'0.00',credit:row.tax}]}
}
export function createDemoHandler({file} = {}) {
  let state = file && existsSync(file) ? JSON.parse(readFileSync(file,'utf8')) : seed()
  const sessions = new Map(), streams = new Map()
  const save = () => {if(file){mkdirSync(resolve(file,'..'),{recursive:true});writeFileSync(file+'.tmp',JSON.stringify(state));renameSync(file+'.tmp',file)}}
  const emit = tenant => {for(const [res,entry] of streams) if(entry.tenant===tenant) for(const event of ['invoice.status_changed','posting.count_changed','risk.score_changed']) res.write(`event: ${event}\ndata: {}\n\n`)}
  const fail = (status,detail) => {throw Object.assign(new Error(detail),{status})}
  return async (req,res,next) => {
    if(!req.url?.startsWith('/api/v1/')) return next?.()
    const url = new URL(req.url,'http://localhost'), path=url.pathname.slice(7), method=req.method
    const send = (data,status=200) => {res.writeHead(status,{'Content-Type':status>=400?'application/problem+json':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(data))}
    try {
      let body = {}; if(method==='POST') {let raw='';for await(const chunk of req){raw+=chunk;if(raw.length>16000) fail(413,'请求过大')}try{body=JSON.parse(raw||'{}')}catch{fail(422,'请求格式不正确')}}
      const cookie = /taxhub_demo=([^;]+)/.exec(req.headers.cookie||'')?.[1]
      if(path==='/auth/login' && method==='POST') {
        if(!['accountant','viewer','tax'].includes(body.account)||body.password!=='demo123') fail(401,'演示账号或密码错误')
        const me={name:body.account==='viewer'?'只读访客':body.account==='tax'?'税务专员':'林晓 · 财务专员',role:body.account,permissions:['invoice:read','risk:read',...(body.account==='viewer'?[]:body.account==='tax'?['risk:write']:['invoice:write','posting:write','risk:write'])],tenants:[{id:'demo-a',name:'云杉科技有限公司（演示）'},{id:'demo-b',name:'云杉商贸有限公司（演示）'}]}
        const token=randomUUID();sessions.set(token,me);res.setHeader('Set-Cookie',`taxhub_demo=${token}; Path=/api/v1; HttpOnly; SameSite=Strict`);return send(me)
      }
      const me=sessions.get(cookie); if(!me) fail(401,'会话已失效，请重新登录')
      if(path==='/auth/logout'){sessions.delete(cookie);for(const [stream,entry] of streams)if(entry.cookie===cookie)stream.end();res.setHeader('Set-Cookie','taxhub_demo=; Path=/api/v1; Max-Age=0; HttpOnly; SameSite=Strict');return send(me)}
      if(path==='/me') return send(me)
      const tenant=req.headers['x-tenant-id']||url.searchParams.get('tenant_id')
      if(!me.tenants.some(t=>t.id===tenant)) fail(403,'没有该主体的访问权限')
      if(path==='/events') {res.writeHead(200,{'Content-Type':'text/event-stream','Cache-Control':'no-cache',Connection:'keep-alive'});res.write(': connected\n\n');streams.set(res,{tenant,cookie});const timer=setInterval(()=>res.write(': heartbeat\n\n'),15000);res.on('close',()=>{clearInterval(timer);streams.delete(res)});return}
      const write = permission => {if(!me.permissions.includes(permission))fail(403,'当前角色无权执行此操作')}
      const rows=state.invoices.filter(r=>r.tenant_id===tenant)
      const getInvoice = id => {const row=rows.find(r=>r.id===id);if(!row)fail(404,'记录不存在或不可访问');return row}
      const paginate = items => {const size=Math.min(100,Math.max(1,Number(url.searchParams.get('page_size'))||20));const page=Math.min(Math.max(1,Math.ceil(items.length/size)),Math.max(1,Number(url.searchParams.get('page'))||1));return {items:items.slice((page-1)*size,page*size),total:items.length,page,page_size:size}}
      const mutation = (operation,action) => {
        const key=req.headers['idempotency-key'], cacheKey=`${tenant}:${me.role}:${operation}:${key}`
        if(key && state.idempotency[cacheKey]) return send(state.idempotency[cacheKey])
        const result=action();if(key)state.idempotency[cacheKey]=structuredClone(result);save();emit(tenant);return send(result)
      }
      const accept = row => {if(row.status!=='pending_posting'||!row.suggestion)fail(409,'建议已变化，请刷新后重试');row.status='posted';row.voucher_id=`v-${row.id}`;row.history.push('采纳建议，演示凭证已生成');return row}
      if(path==='/dashboard/summary') return send({pending:rows.filter(r=>r.status==='pending_posting').length,filings:0,risks:state.risks.filter(r=>r.tenant_id===tenant&&r.status!=='closed').length,invoices:rows.length,trend:[6,7,8,9,10,11].map((m,i)=>({month:`${m}月`,input:[12,16,11,20,18,rows.filter(r=>r.direction==='进项').length][i],output:[6,8,5,9,7,rows.filter(r=>r.direction==='销项').length][i]}))})
      if(path==='/invoices'&&method==='GET') {const q=url.searchParams.get('q')?.trim().toLowerCase()||'', status=url.searchParams.get('status'),period=url.searchParams.get('period');return send(paginate(rows.filter(r=>(!q||`${r.number} ${r.partner}`.toLowerCase().includes(q))&&(!status||r.status===status)&&(!period||r.date.startsWith(period))).reverse()))}
      if(path==='/invoices'&&method==='POST') {write('invoice:write');if(!/^DEMO-[A-Za-z0-9-]{1,40}$/.test(body.number||'')||!body.partner?.trim()||body.partner.length>80)fail(422,'发票号码须以 DEMO- 开头，交易对方为必填（最多 80 字）');if(rows.some(r=>r.number===body.number))fail(409,'该样例票据已存在，请在列表中查看');return mutation('import',()=>{const row={...seed().invoices[0],id:`inv-${Date.now()}`,tenant_id:tenant,number:body.number,partner:body.partner.trim(),status:'collected',suggestion:null,voucher_id:'',history:['模拟采集完成']};state.invoices.push(row);return row})}
      const match=/^\/invoices\/([^/]+)(?:\/(verify|suggestions))?$/.exec(path)
      if(match){const row=getInvoice(match[1]);if(method==='GET')return send(row);if(method!=='POST')fail(405,'不支持的请求');write(match[2]==='verify'?'invoice:write':'posting:write');return mutation(path,()=>{if(match[2]==='verify'){if(!['collected','verify_failed'].includes(row.status))fail(409,'当前状态不可查验');row.status='verified';row.history.push('模拟查验通过（未连接税局）')}else {if(row.status!=='verified')fail(409,'请先完成查验');row.suggestion=suggestion(row);row.status='pending_posting';row.history.push('已生成固定演示建议')}return row})}
      if(path==='/suggestions/batch-accept'&&method==='POST'){write('posting:write');if(!Array.isArray(body.ids)||body.ids.length>100)fail(422,'请选择不超过 100 条建议');return mutation(path,()=>{const result={processed:[],skipped:[]};for(const id of new Set(body.ids)){const row=rows.find(r=>r.suggestion?.id===id);if(row?.status==='pending_posting'&&row.suggestion.confidence>=0.95&&!row.suggestion.need_review){accept(row);result.processed.push(id)}else result.skipped.push(id)}return result})}
      const acceptMatch=/^\/suggestions\/(.+)\/accept$/.exec(path)
      if(acceptMatch&&method==='POST'){write('posting:write');return mutation(path,()=>{const row=rows.find(r=>r.suggestion?.id===acceptMatch[1]);if(!row)fail(404,'记录不存在或不可访问');return accept(row)})}
      if(path.startsWith('/vouchers/')) {const row=rows.find(r=>r.voucher_id===path.slice(10));if(!row)fail(404,'记录不存在或不可访问');return send(voucher(row))}
      if(path==='/risks')return send(paginate(state.risks.filter(r=>r.tenant_id===tenant)))
      const riskMatch=/^\/risks\/([^/]+)\/transition$/.exec(path)
      if(riskMatch&&method==='POST'){write('risk:write');const risk=state.risks.find(r=>r.id===riskMatch[1]&&r.tenant_id===tenant);if(!risk)fail(404,'记录不存在或不可访问');if(risk.status==='closed')fail(409,'风险已关闭');if(risk.status==='open'&&!['财务专员','税务专员'].includes(body.owner))fail(422,'请选择演示授权负责人');if(!body.note?.trim())fail(422,'请填写处置说明');return mutation(path,()=>{risk.owner=body.owner||risk.owner;risk.status={open:'assigned',assigned:'investigating',investigating:'closed'}[risk.status];risk.history.push(body.note);return risk})}
      if(path==='/reimbursements')return send(paginate(tenant==='demo-a'?[{id:'RE-DEMO-001',reason:'客户拜访差旅费',applicant:'陈安（演示）',amount:'1280.00',date:'2026-11-12',status:'审批中'},{id:'RE-DEMO-002',reason:'研发部办公采购',applicant:'李可（演示）',amount:'680.00',date:'2026-11-10',status:'已完成'}]:[]))
      fail(404,'接口不存在')
    }catch(error){send({title:'请求未完成',status:error.status||500,detail:error.status?error.message:'演示服务异常，请重试',trace_id:randomUUID()},error.status||500)}
  }
}
/** @returns {import('vite').Plugin} */
export function demoPlugin(){return {name:'taxhub-local-demo',apply:'serve',configureServer(server){server.middlewares.use(createDemoHandler({file:resolve('.demo/state.json')}))}}}
