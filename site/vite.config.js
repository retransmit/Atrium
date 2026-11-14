import { defineConfig } from 'vite';
import fs from 'fs';
import path from 'path';

function htmlIncludePlugin() {
  return {
    name: 'html-include',
    handleHotUpdate({ file, server }) {
      if (file.endsWith('.html') && file.includes('/src/components/')) {
        server.ws.send({ type: 'full-reload', path: '*' });
      }
    },
    transformIndexHtml: {
      order: 'pre',
      handler(html, ctx) {
        return html.replace(/<include\s+src="([^"]+)"\s*\/>/g, (match, src) => {
          const filePath = path.resolve(ctx.filename ? path.dirname(ctx.filename) : process.cwd(), src);
          if (fs.existsSync(filePath)) {
            return fs.readFileSync(filePath, 'utf-8');
          }
          return match;
        });
      }
    }
  };
}

export default defineConfig({
  plugins: [htmlIncludePlugin()],
  // Served at the root of a custom domain (atrium.kurai.cloud). Under the bare
  // GitHub Pages project URL it would need base: '/Atrium/' instead, or every
  // asset 404s. Anything built in JS should use import.meta.env.BASE_URL.
  base: '/',
  server: {
    allowedHosts: [
      'atrium.betelgeuse.fun'
    ]
  }
});
