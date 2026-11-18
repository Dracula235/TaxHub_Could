import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { demoPlugin } from './demo/server.mjs'

export default defineConfig({
  plugins: [vue(), demoPlugin()],
  server: { port: 5173, strictPort: true },
})
