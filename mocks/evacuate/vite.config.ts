import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// base: './' so dist/ can be served from any path (static hosting / file share).
export default defineConfig({
  base: './',
  plugins: [react()],
});
