import { useState, useEffect } from 'react';
import { useSearchParams, Link } from 'react-router-dom';
import { authService } from '../services/services';

export default function VerifyEmail() {
    const [searchParams] = useSearchParams();
    const [status, setStatus] = useState('loading');
    const token = searchParams.get('token');

    useEffect(() => {
        if (!token) {
            setStatus('error');
            return;
        }
        authService.verifyEmail(token)
            .then(() => setStatus('success'))
            .catch(() => setStatus('error'));
    }, [token]);

    return (
        <div className="auth-page">
            <div className="card shadow-sm" style={{ maxWidth: '450px', width: '100%' }}>
                <div className="card-body text-center p-5">
                    {status === 'loading' && (
                        <>
                            <div className="spinner-border text-primary mb-3" style={{ width: '3rem', height: '3rem' }}></div>
                            <h5>Verificando tu correo...</h5>
                        </>
                    )}
                    {status === 'success' && (
                        <>
                            <div className="mb-3" style={{ fontSize: '4rem' }}>✅</div>
                            <h4 className="fw-bold text-success">¡Correo verificado!</h4>
                            <p className="text-muted">Tu cuenta ha sido activada exitosamente.</p>
                            <Link to="/login" className="btn btn-primary mt-2">
                                <i className="bi bi-box-arrow-in-right me-1"></i> Iniciar sesión
                            </Link>
                        </>
                    )}
                    {status === 'error' && (
                        <>
                            <div className="mb-3" style={{ fontSize: '4rem' }}>❌</div>
                            <h4 className="fw-bold text-danger">Error de verificación</h4>
                            <p className="text-muted">El enlace es inválido o ha expirado.</p>
                            <Link to="/" className="btn btn-outline-primary mt-2">Volver al inicio</Link>
                        </>
                    )}
                </div>
            </div>
        </div>
    );
}
