import { QueryClient } from '@tanstack/vue-query'
import type { paths, components } from './schema'

export const queryClient = new QueryClient({defaultOptions:{queries:{retry:false,staleTime:15_000}}})
export type Model<K extends keyof components['schemas']> = components['schemas'][K]
type Endpoint = keyof paths
type Method<P extends Endpoint> = Extract<keyof paths[P], 'get' | 'post'>
type Result<P extends Endpoint,M extends Method<P>> = paths[P][M] extends {responses:{200:{content:{'application/json':infer R}}}} ? R : never
export class ApiError extends Error { constructor(public status:number, message:string, public traceId=''){super(message)} }
export async function api<P extends Endpoint,M extends Method<P>>(path:P, method:M, options:{tenant?:string;params?:Record<string,string|number>;id?:string;body?:unknown;key?:string}={}):Promise<Result<P,M>> {
  const endpoint=options.id ? path.replace('{id}',encodeURIComponent(options.id)) : path
  const params=new URLSearchParams();Object.entries(options.params||{}).forEach(([k,v])=>{if(v!=='')params.set(k,String(v))})
  const response=await fetch(`/api/v1${endpoint}?${params}`,{method:method.toUpperCase(),credentials:'same-origin',headers:{'Content-Type':'application/json',...(options.tenant?{'X-Tenant-ID':options.tenant}:{}),...(options.key?{'Idempotency-Key':options.key}:{})},body:options.body?JSON.stringify(options.body):undefined})
  const data:unknown=await response.json()
  if(!response.ok){const p=data as Partial<Model<'Problem'>>;if(response.status===401&&path!=='/auth/login'&&path!=='/me')window.dispatchEvent(new Event('session-expired'));throw new ApiError(response.status,p.detail||'请求失败，请重试',p.trace_id)}
  return data as Result<P,M>
}
