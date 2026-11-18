// Development-only contract. Replace with FastAPI's OpenAPI before integration.
import { writeFileSync } from 'node:fs'
const str = { type: 'string' }, num = { type: 'number' }, bool = { type: 'boolean' }
const ref = name => ({ $ref: `#/components/schemas/${name}` })
const arr = items => ({ type: 'array', items })
const obj = properties => ({ type: 'object', properties, required: Object.keys(properties), additionalProperties: false })
const schemas = {
  Me: obj({ name: str, role: str, permissions: arr(str), tenants: arr(obj({ id: str, name: str })) }),
  Signal: obj({ name: str, weight: str, value: str, source: str }),
  Suggestion: obj({ id: str, account: str, confidence: num, need_review: bool, reason: str, signals: arr(ref('Signal')) }),
  Invoice: obj({ id: str, tenant_id: str, number: str, kind: str, direction: str, partner: str, date: str, amount: str, tax: str, total: str,
    status: { type: 'string', enum: ['collected','verifying','verified','verify_failed','pending_posting','posted','archived','voided','red_flushed'] },
    item: str, voucher_id: str, suggestion: { type: 'object', allOf: [ref('Suggestion')], nullable: true }, history: arr(str) }),
  Voucher: obj({ id: str, number: str, period: str, summary: str, debit_total: str, credit_total: str, lines: arr(obj({ account: str, debit: str, credit: str })) }),
  Risk: obj({ id: str, tenant_id: str, title: str, severity: str, invoice_id: str, owner: str, status: str, description: str, history: arr(str) }),
  Reimbursement: obj({ id: str, reason: str, applicant: str, amount: str, date: str, status: str }),
  Summary: obj({ pending: num, filings: num, risks: num, invoices: num, trend: arr(obj({ month: str, input: num, output: num })) }),
  Login: obj({ account: str, password: str }),
  Import: obj({ number: str, partner: str }),
  Transition: obj({ owner: str, note: str }),
  Batch: obj({ ids: arr(str) }),
  BatchResult: obj({ processed: arr(str), skipped: arr(str) }),
  Problem: obj({ title: str, detail: str, status: num, trace_id: str }),
}
for (const name of ['Invoice','Risk','Reimbursement']) schemas[`${name}Page`] = obj({ items: arr(ref(name)), total: num, page: num, page_size: num })
const paths = {}
function route(path, method, response, request) {
  const parameters = [...path.matchAll(/\{(\w+)\}/g)].map(m => ({name:m[1], in:'path', required:true, schema:str}))
  paths[path] ??= {}
  paths[path][method] = { parameters, responses: { 200: { description:'Development response', content:{'application/json':{schema:ref(response)}} } }, ...(request ? {requestBody:{required:true,content:{'application/json':{schema:ref(request)}}}} : {}) }
}
route('/auth/login','post','Me','Login'); route('/me','get','Me'); route('/auth/logout','post','Me')
route('/dashboard/summary','get','Summary'); route('/invoices','get','InvoicePage'); route('/invoices','post','Invoice','Import')
route('/invoices/{id}','get','Invoice'); route('/invoices/{id}/verify','post','Invoice'); route('/invoices/{id}/suggestions','post','Invoice')
route('/suggestions/{id}/accept','post','Invoice'); route('/suggestions/batch-accept','post','BatchResult','Batch'); route('/vouchers/{id}','get','Voucher')
route('/risks','get','RiskPage'); route('/risks/{id}/transition','post','Risk','Transition'); route('/reimbursements','get','ReimbursementPage')
paths['/events'] = {get:{responses:{200:{description:'Authenticated cookie SSE stream; events invalidate queries',content:{'text/event-stream':{schema:str}}}}}}
writeFileSync(new URL('./openapi.json', import.meta.url), JSON.stringify({openapi:'3.0.3', info:{title:'Taxhub local DEMO contract — not the production API',version:'0.1.0'},servers:[{url:'/api/v1'}],paths,components:{schemas}},null,2)+'\n')
