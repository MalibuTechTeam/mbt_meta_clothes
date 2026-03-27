import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

export default defineConfig({
  plugins: [
    tailwindcss(),
    react(),
  ],
  base: './', // Important for FiveM HTML relative paths
  build: {
    outDir: 'dist',
    emptyOutDir: true,
  }
})
