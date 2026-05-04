import { Link } from 'react-router-dom';

export default function NotFound() {
    return (
        <div className="auth-page">
            <div className="text-center">
                <div style={{ fontSize: '6rem' }}>🐾</div>
                <h1 className="fw-bold" style={{ fontSize: '5rem', color: 'var(--primary)' }}>404</h1>
                <h4 className="mb-3">Página no encontrada</h4>
                <p className="text-muted mb-4">La página que buscas no existe o fue movida.</p>
                <Link to="/" className="btn btn-primary">
                    <i className="bi bi-house me-1"></i> Volver al inicio
                </Link>
            </div>
        </div>
    );
}
