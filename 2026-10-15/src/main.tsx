import React from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import { useWorkspace } from './useWorkspace';
import './styles.css';

function Root() { return <App controller={useWorkspace()} />; }
const root = createRoot(document.getElementById('root')!);
root.render(<React.StrictMode><Root /></React.StrictMode>);
if (import.meta.hot) import.meta.hot.dispose(() => root.unmount());
