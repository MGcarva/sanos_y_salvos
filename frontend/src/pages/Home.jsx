import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { dashboardService } from '../services/services';
import { useAuth } from '../contexts/AuthContext';
import ReporteMap from '../components/ReporteMap';

export default function Home() {
    const { user } = useAuth();
    const [data, setData] = useState({ reportes: [], heatmap: [] });
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        dashboardService.get()
            .then(res => setData(res.data))
            .catch(() => setData({ reportes: [], heatmap: [] }))
            .finally(() => setLoading(false));
    }, []);

    const perdidos = data.reportes.filter(r => r.tipo === 'PERDIDO');
    const encontrados = data.reportes.filter(r => r.tipo === 'ENCONTRADO');

    return (
        <>
            {/* Hero Section */}
            <section className="hero-section">
                <div className="container position-relative" style={{ zIndex: 1 }}>
                    <div className="row align-items-center">
                        <div className="col-lg-7">
                            <h1 className="hero-title mb-3">
                                Reunimos mascotas<br />con sus familias
                            </h1>
                            <p className="hero-subtitle mb-4">
                                Reporta mascotas perdidas o encontradas, y nuestro sistema inteligente
                                de geolocalización y coincidencias te ayudará a encontrarlas.
                            </p>
                            <div className="d-flex gap-3 flex-wrap">
                                {user ? (
                                    <>
                                        <Link to="/reportar" className="btn btn-light btn-lg fw-bold px-4">
                                            <i className="bi bi-plus-circle me-2"></i>Crear Reporte
                                        </Link>
                                        <Link to="/mapa" className="btn btn-outline-light btn-lg px-4">
                                            <i className="bi bi-map me-2"></i>Ver Mapa
                                        </Link>
                                    </>
                                ) : (
                                    <>
                                        <Link to="/register" className="btn btn-light btn-lg fw-bold px-4">
                                            <i className="bi bi-person-plus me-2"></i>Crear Cuenta
                                        </Link>
                                        <Link to="/mapa" className="btn btn-outline-light btn-lg px-4">
                                            <i className="bi bi-map me-2"></i>Explorar Mapa
                                        </Link>
                                    </>
                                )}
                            </div>
                        </div>
                        <div className="col-lg-5 text-center d-none d-lg-block">
                            <div style={{ fontSize: '10rem', lineHeight: 1, opacity: 0.3 }}>🐾</div>
                        </div>
                    </div>
                </div>
            </section>

            <div className="container">
                {/* Stats */}
                <div className="row g-4 mb-5" style={{ marginTop: '-2rem' }}>
                    <div className="col-md-4">
                        <div className="stat-card perdidos">
                            <div className="stat-number text-danger">{perdidos.length}</div>
                            <div className="stat-label">Mascotas Perdidas</div>
                            <i className="bi bi-search-heart" style={{ fontSize: '1.5rem', color: '#e6394640', marginTop: '0.5rem' }}></i>
                        </div>
                    </div>
                    <div className="col-md-4">
                        <div className="stat-card encontrados">
                            <div className="stat-number text-success">{encontrados.length}</div>
                            <div className="stat-label">Mascotas Encontradas</div>
                            <i className="bi bi-check-circle" style={{ fontSize: '1.5rem', color: '#2a9d8f40', marginTop: '0.5rem' }}></i>
                        </div>
                    </div>
                    <div className="col-md-4">
                        <div className="stat-card total">
                            <div className="stat-number text-primary">{data.reportes.length}</div>
                            <div className="stat-label">Reportes Activos</div>
                            <i className="bi bi-clipboard-data" style={{ fontSize: '1.5rem', color: '#4361ee40', marginTop: '0.5rem' }}></i>
                        </div>
                    </div>
                </div>

                {/* Map Preview */}
                <div className="card mb-5">
                    <div className="card-header bg-white py-3 d-flex justify-content-between align-items-center">
                        <div>
                            <h5 className="mb-0 fw-bold">
                                <i className="bi bi-geo-alt-fill text-primary me-2"></i>
                                Mapa de Reportes
                            </h5>
                        </div>
                        <Link to="/mapa" className="btn btn-sm btn-outline-primary">
                            <i className="bi bi-arrows-fullscreen me-1"></i> Ver completo
                        </Link>
                    </div>
                    <div className="card-body p-0">
                        {loading ? (
                            <div className="page-loading">
                                <div className="spinner-border" role="status"></div>
                            </div>
                        ) : (
                            <ReporteMap reportes={data.heatmap.length > 0 ? data.heatmap : data.reportes} />
                        )}
                    </div>
                </div>

                {/* Recent Reports */}
                <div className="section-header">
                    <h4 className="section-title">
                        <i className="bi bi-clock-history me-2 text-primary"></i>
                        Últimos Reportes
                    </h4>
                    <Link to="/mapa" className="btn btn-sm btn-outline-primary">Ver todos</Link>
                </div>

                {loading ? (
                    <div className="page-loading"><div className="spinner-border"></div></div>
                ) : data.reportes.length === 0 ? (
                    <div className="empty-state">
                        <i className="bi bi-inbox"></i>
                        <h5>No hay reportes aún</h5>
                        <p>Sé el primero en reportar una mascota</p>
                        <Link to="/reportar" className="btn btn-primary">Crear reporte</Link>
                    </div>
                ) : (
                    <div className="row g-4 mb-4">
                        {data.reportes.slice(0, 6).map(reporte => (
                            <div key={reporte.id} className="col-md-4">
                                <Link to={`/reporte/${reporte.id}`} className="text-decoration-none">
                                    <div className="card card-reporte h-100">
                                        <div className="card-img-wrapper">
                                            {reporte.fotoUrl ? (
                                                <img src={reporte.fotoUrl} className="card-img-top"
                                                     alt={reporte.nombre || reporte.especie} />
                                            ) : (
                                                <div className="card-img-placeholder">
                                                    {reporte.especie?.toLowerCase().includes('perro') ? '🐕' :
                                                     reporte.especie?.toLowerCase().includes('gato') ? '🐈' : '🐾'}
                                                </div>
                                            )}
                                            <span className={`badge ${reporte.tipo === 'PERDIDO' ? 'badge-perdido' : 'badge-encontrado'} position-absolute`}
                                                  style={{ top: '12px', left: '12px' }}>
                                                <i className={`bi ${reporte.tipo === 'PERDIDO' ? 'bi-exclamation-triangle' : 'bi-check-circle'} me-1`}></i>
                                                {reporte.tipo}
                                            </span>
                                        </div>
                                        <div className="card-body">
                                            <h6 className="fw-bold text-dark mb-1">
                                                {reporte.nombre || reporte.especie}
                                            </h6>
                                            <div className="text-muted small mb-2">
                                                {reporte.raza && <span className="me-2">{reporte.raza}</span>}
                                                {reporte.color && <span className="me-2">· {reporte.color}</span>}
                                                {reporte.tamano && <span>· {reporte.tamano === 'PEQUENO' ? 'Pequeño' : reporte.tamano === 'MEDIANO' ? 'Mediano' : 'Grande'}</span>}
                                            </div>
                                            <p className="card-text text-muted small mb-2">
                                                {reporte.descripcion?.substring(0, 80)}{reporte.descripcion?.length > 80 ? '...' : ''}
                                            </p>
                                            {reporte.direccion && (
                                                <small className="text-muted">
                                                    <i className="bi bi-geo-alt me-1"></i>{reporte.direccion}
                                                </small>
                                            )}
                                        </div>
                                    </div>
                                </Link>
                            </div>
                        ))}
                    </div>
                )}

                {/* How it works */}
                <div className="card bg-white mb-4">
                    <div className="card-body py-5">
                        <h4 className="text-center fw-bold mb-4">¿Cómo funciona?</h4>
                        <div className="row g-4 text-center">
                            <div className="col-md-3">
                                <div className="rounded-circle bg-primary bg-opacity-10 d-inline-flex align-items-center justify-content-center mb-3"
                                     style={{ width: '70px', height: '70px' }}>
                                    <i className="bi bi-person-plus text-primary" style={{ fontSize: '1.8rem' }}></i>
                                </div>
                                <h6 className="fw-bold">1. Regístrate</h6>
                                <p className="text-muted small">Crea tu cuenta como usuario o refugio</p>
                            </div>
                            <div className="col-md-3">
                                <div className="rounded-circle bg-danger bg-opacity-10 d-inline-flex align-items-center justify-content-center mb-3"
                                     style={{ width: '70px', height: '70px' }}>
                                    <i className="bi bi-megaphone text-danger" style={{ fontSize: '1.8rem' }}></i>
                                </div>
                                <h6 className="fw-bold">2. Reporta</h6>
                                <p className="text-muted small">Publica un reporte con foto y ubicación</p>
                            </div>
                            <div className="col-md-3">
                                <div className="rounded-circle bg-warning bg-opacity-10 d-inline-flex align-items-center justify-content-center mb-3"
                                     style={{ width: '70px', height: '70px' }}>
                                    <i className="bi bi-robot text-warning" style={{ fontSize: '1.8rem' }}></i>
                                </div>
                                <h6 className="fw-bold">3. Algoritmo</h6>
                                <p className="text-muted small">Nuestro sistema busca coincidencias automáticamente</p>
                            </div>
                            <div className="col-md-3">
                                <div className="rounded-circle bg-success bg-opacity-10 d-inline-flex align-items-center justify-content-center mb-3"
                                     style={{ width: '70px', height: '70px' }}>
                                    <i className="bi bi-heart text-success" style={{ fontSize: '1.8rem' }}></i>
                                </div>
                                <h6 className="fw-bold">4. Reencuentro</h6>
                                <p className="text-muted small">Recibe notificaciones cuando haya coincidencias</p>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
}
