import { Link, NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';

export default function Navbar() {
    const { user, logout } = useAuth();
    const navigate = useNavigate();

    const handleLogout = () => {
        logout();
        navigate('/login');
    };

    return (
        <nav className="navbar navbar-expand-lg navbar-dark navbar-custom">
            <div className="container">
                <Link className="navbar-brand" to="/">
                    <i className="bi bi-heart-pulse-fill me-2"></i>
                    Sanos y Salvos
                </Link>
                <button className="navbar-toggler border-0" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                    <span className="navbar-toggler-icon"></span>
                </button>
                <div className="collapse navbar-collapse" id="navbarNav">
                    <ul className="navbar-nav me-auto">
                        <li className="nav-item">
                            <NavLink className="nav-link" to="/">
                                <i className="bi bi-house-fill me-1"></i> Inicio
                            </NavLink>
                        </li>
                        <li className="nav-item">
                            <NavLink className="nav-link" to="/mapa">
                                <i className="bi bi-geo-alt-fill me-1"></i> Mapa
                            </NavLink>
                        </li>
                        {user && (
                            <>
                                <li className="nav-item">
                                    <NavLink className="nav-link" to="/reportar">
                                        <i className="bi bi-plus-circle-fill me-1"></i> Reportar
                                    </NavLink>
                                </li>
                                <li className="nav-item">
                                    <NavLink className="nav-link" to="/mis-reportes">
                                        <i className="bi bi-list-check me-1"></i> Mis Reportes
                                    </NavLink>
                                </li>
                            </>
                        )}
                    </ul>
                    <ul className="navbar-nav">
                        {user ? (
                            <li className="nav-item dropdown">
                                <a className="nav-link dropdown-toggle d-flex align-items-center" href="#" role="button"
                                   data-bs-toggle="dropdown">
                                    <div className="rounded-circle bg-white bg-opacity-25 d-flex align-items-center justify-content-center me-2"
                                         style={{ width: '32px', height: '32px' }}>
                                        <i className="bi bi-person-fill"></i>
                                    </div>
                                    {user.nombre}
                                </a>
                                <ul className="dropdown-menu dropdown-menu-end shadow-lg border-0">
                                    <li className="px-3 py-2">
                                        <div className="fw-bold">{user.nombre}</div>
                                        <small className="text-muted">{user.email}</small>
                                        <div><span className="badge bg-primary bg-opacity-10 text-primary mt-1">{user.rol}</span></div>
                                    </li>
                                    <li><hr className="dropdown-divider" /></li>
                                    <li>
                                        <Link className="dropdown-item" to="/mis-reportes">
                                            <i className="bi bi-list-check me-2"></i> Mis Reportes
                                        </Link>
                                    </li>
                                    <li><hr className="dropdown-divider" /></li>
                                    <li>
                                        <button className="dropdown-item text-danger" onClick={handleLogout}>
                                            <i className="bi bi-box-arrow-right me-2"></i> Cerrar sesión
                                        </button>
                                    </li>
                                </ul>
                            </li>
                        ) : (
                            <>
                                <li className="nav-item">
                                    <Link className="nav-link" to="/login">
                                        <i className="bi bi-box-arrow-in-right me-1"></i> Ingresar
                                    </Link>
                                </li>
                                <li className="nav-item ms-1">
                                    <Link className="btn btn-light btn-sm fw-bold px-3" to="/register"
                                          style={{ borderRadius: '20px', marginTop: '4px' }}>
                                        Registrarse
                                    </Link>
                                </li>
                            </>
                        )}
                    </ul>
                </div>
            </div>
        </nav>
    );
}
