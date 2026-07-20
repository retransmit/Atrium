import 'beercss';
import 'material-dynamic-colors';
import './style.css';

// Wait for UI to initialize, then set a vibrant theme
setTimeout(() => {
  if (window.ui) {
    window.ui('theme', '#7C4DFF'); // Deep purple accent for the Material 3 generation
  }
}, 100);
