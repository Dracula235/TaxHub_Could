import { ref } from 'vue'
import { ElMessage } from 'element-plus'
import { queryClient } from '../api/client'
export function useAction(){const busy=ref(false);const keys=new Map<string,string>();async function run(label:string,action:(key:string)=>Promise<unknown>,success='操作完成'){if(busy.value)return false;busy.value=true;const key=keys.get(label)||crypto.randomUUID();keys.set(label,key);try{await action(key);keys.delete(label);await queryClient.invalidateQueries();ElMessage.success(success);return true}catch(e){ElMessage.error(e instanceof Error?e.message:'操作失败，请重试');return false}finally{busy.value=false}}return {busy,run}}
