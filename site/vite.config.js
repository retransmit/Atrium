import { defineConfig } from 'vite';

export default defineConfig({
  // Served from a GitHub Pages project subpath (retransmit.github.io/Atrium/),
  // so built asset URLs have to carry that prefix. Without it the root-relative
  // /assets/... paths in index.html resolve against the domain root and 404.
  // Anything built in JS should use import.meta.env.BASE_URL, not a literal.
  base: '/Atrium/',
  server: {
    allowedHosts: [
      'atrium.betelgeuse.fun'
    ]
  }
});
