import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export default function Login() {
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [showPass, setShowPass] = useState(false);
    const { login, loading } = useAuth();
    const navigate = useNavigate();

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        const result = await login(email, password);
        if (result.success) {
            navigate('/');
        } else {
            setError(result.message);
        }
    };

    return (
        <div className="auth-page">
            <div className="auth-card">
                <div className="card shadow-lg">
                    <div className="card-body">
                        <div className="auth-header">
                            <div className="mb-3" style={{ fontSize: '3rem' }}>🐾</div>
                            <h2>Bienvenido de vuelta</h2>
                            <p>Inicia sesión en tu cuenta</p>
                        </div>
                        {error && (
                            <div className="alert alert-danger d-flex align-items-center">
                                <i className="bi bi-exclamation-triangle-fill me-2"></i>
                                {error}
                            </div>
                        )}
                        <form onSubmit={handleSubmit}>
                            <div className="mb-3">
                                <label className="form-label">
                                    <i className="bi bi-envelope me-1"></i> Email
                                </label>
                                <input type="email" className="form-control form-control-lg"
                                       placeholder="tu@email.com"
                                       value={email} onChange={e => setEmail(e.target.value)} required />
                            </div>
                            <div className="mb-4">
                                <label className="form-label">
                                    <i className="bi bi-lock me-1"></i> Contraseña
                                </label>
                                <div className="input-group">
                                    <input type={showPass ? 'text' : 'password'}
                                           className="form-control form-control-lg"
                                           placeholder="••••••••"
                                           value={password} onChange={e => setPassword(e.target.value)} required />
                                    <button type="button" className="btn btn-outline-secondary"
                                            onClick={() => setShowPass(!showPass)}>
                                        <i className={`bi bi-eye${showPass ? '-slash' : ''}`}></i>
                                    </button>
                                </div>
                            </div>
                            <button type="submit" className="btn btn-primary btn-lg w-100 mb-3" disabled={loading}>
                                {loading ? (
                                    <><span className="spinner-border spinner-border-sm me-2"></span>Ingresando...</>
                                ) : (
                                    <><i className="bi bi-box-arrow-in-right me-2"></i>Ingresar</>
                                )}
                            </button>
                        </form>
                        <p className="text-center mb-0">
                            ¿No tienes cuenta?{' '}
                            <Link to="/register" className="fw-bold text-decoration-none">Regístrate</Link>
                        </p>
                    </div>
                </div>
            </div>
        </div>
    );
}
