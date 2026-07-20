import 'beercss';
import 'material-dynamic-colors';
// Self-hosted so the site makes no third-party requests, matching what the app
// claims about itself. Bundled by Vite, never fetched from a font CDN.
import '@fontsource-variable/archivo';
import './style.css';

// Wait for UI to initialize, then set a vibrant theme
setTimeout(() => {
  if (window.ui) {
    window.ui('theme', '#7C4DFF'); // Deep purple accent for the Material 3 generation
  }
}, 100);
