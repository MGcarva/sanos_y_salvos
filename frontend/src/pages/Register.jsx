import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export default function Register() {
    const [form, setForm] = useState({ nombre: '', email: '', password: '', confirmPassword: '', rol: 'USER' });
    const [error, setError] = useState('');
    const [showPass, setShowPass] = useState(false);
    const { register, loading } = useAuth();
    const navigate = useNavigate();

    const handleChange = (e) => setForm({ ...form, [e.target.name]: e.target.value });

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        if (form.password !== form.confirmPassword) {
            setError('Las contraseñas no coinciden');
            return;
        }
        if (form.password.length < 8) {
            setError('La contraseña debe tener al menos 8 caracteres');
            return;
        }
        const result = await register(form.nombre, form.email, form.password, form.rol);
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
                            <h2>Crear cuenta</h2>
                            <p>Únete a la comunidad de Sanos y Salvos</p>
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
                                    <i className="bi bi-person me-1"></i> Nombre completo
                                </label>
                                <input type="text" name="nombre" className="form-control form-control-lg"
                                       placeholder="Tu nombre"
                                       value={form.nombre} onChange={handleChange} required minLength={2} />
                            </div>
                            <div className="mb-3">
                                <label className="form-label">
                                    <i className="bi bi-envelope me-1"></i> Email
                                </label>
                                <input type="email" name="email" className="form-control form-control-lg"
                                       placeholder="tu@email.com"
                                       value={form.email} onChange={handleChange} required />
                            </div>
                            <div className="mb-3">
                                <label className="form-label">
                                    <i className="bi bi-lock me-1"></i> Contraseña
                                </label>
                                <div className="input-group">
                                    <input type={showPass ? 'text' : 'password'} name="password"
                                           className="form-control form-control-lg"
                                           placeholder="Mínimo 8 caracteres"
                                           value={form.password} onChange={handleChange} required minLength={8} />
                                    <button type="button" className="btn btn-outline-secondary"
                                            onClick={() => setShowPass(!showPass)}>
                                        <i className={`bi bi-eye${showPass ? '-slash' : ''}`}></i>
                                    </button>
                                </div>
                            </div>
                            <div className="mb-3">
                                <label className="form-label">
                                    <i className="bi bi-lock-fill me-1"></i> Confirmar contraseña
                                </label>
                                <input type={showPass ? 'text' : 'password'} name="confirmPassword"
                                       className="form-control form-control-lg"
                                       placeholder="Repite la contraseña"
                                       value={form.confirmPassword} onChange={handleChange} required />
                            </div>
                            <div className="mb-4">
                                <label className="form-label">
                                    <i className="bi bi-shield me-1"></i> Tipo de cuenta
                                </label>
                                <div className="d-flex gap-3">
                                    <div className={`flex-fill border rounded-3 p-3 text-center cursor-pointer ${form.rol === 'USER' ? 'border-primary bg-primary bg-opacity-10' : ''}`}
                                         style={{ cursor: 'pointer' }}
                                         onClick={() => setForm({ ...form, rol: 'USER' })}>
                                        <i className="bi bi-person-fill d-block mb-1" style={{ fontSize: '1.5rem' }}></i>
                                        <div className="fw-bold small">Usuario</div>
                                        <div className="text-muted" style={{ fontSize: '0.7rem' }}>Busco mi mascota</div>
                                    </div>
                                    <div className={`flex-fill border rounded-3 p-3 text-center ${form.rol === 'REFUGIO' ? 'border-success bg-success bg-opacity-10' : ''}`}
                                         style={{ cursor: 'pointer' }}
                                         onClick={() => setForm({ ...form, rol: 'REFUGIO' })}>
                                        <i className="bi bi-house-heart-fill d-block mb-1" style={{ fontSize: '1.5rem' }}></i>
                                        <div className="fw-bold small">Refugio</div>
                                        <div className="text-muted" style={{ fontSize: '0.7rem' }}>Soy un refugio animal</div>
                                    </div>
                                </div>
                            </div>
                            <button type="submit" className="btn btn-primary btn-lg w-100 mb-3" disabled={loading}>
                                {loading ? (
                                    <><span className="spinner-border spinner-border-sm me-2"></span>Registrando...</>
                                ) : (
                                    <><i className="bi bi-person-plus me-2"></i>Crear cuenta</>
                                )}
                            </button>
                        </form>
                        <p className="text-center mb-0">
                            ¿Ya tienes cuenta?{' '}
                            <Link to="/login" className="fw-bold text-decoration-none">Inicia sesión</Link>
                        </p>
                    </div>
                </div>
            </div>
        </div>
    );
}
