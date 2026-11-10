import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import './styles/tokens.css';
import './styles/global.css';
import { AppProvider } from './state/store';
import { LiveAlertsProvider } from './live/LiveAlerts';
import App from './App';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AppProvider>
      <LiveAlertsProvider>
        <App />
      </LiveAlertsProvider>
    </AppProvider>
  </StrictMode>,
);
