import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from '../contexts/AuthContext';
import App from '../App';

const renderApp = () => {
    return render(
        <App />
    );
};

describe('App', () => {
    it('renders the navbar', () => {
        renderApp();
        const elements = screen.getAllByText('Sanos y Salvos');
        expect(elements.length).toBeGreaterThanOrEqual(1);
    });

    it('renders the home page by default', () => {
        renderApp();
        const elements = screen.getAllByText(/Sanos y Salvos/);
        expect(elements.length).toBeGreaterThanOrEqual(1);
    });
});
