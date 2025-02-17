import { defineConfig } from 'vite'
import elm from 'vite-plugin-elm-watch'

export default defineConfig({
  plugins: [elm()],
  root: './',
  build: {
    outDir: 'dist',
  },
  publicDir: 'public'
})
