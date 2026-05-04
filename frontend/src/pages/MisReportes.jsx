import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { reportesService, coincidenciasService } from '../services/services';

function formatDate(dateStr) {
    if (!dateStr) return '';
    return new Date(dateStr).toLocaleDateString('es-CO', { year: 'numeric', month: 'short', day: 'numeric' });
}

function formatTamano(t) {
    if (t === 'PEQUENO') return 'Pequeño';
    if (t === 'MEDIANO') return 'Mediano';
    if (t === 'GRANDE') return 'Grande';
    return t;
}

export default function MisReportes() {
    const [reportes, setReportes] = useState([]);
    const [coincidencias, setCoincidencias] = useState({});
    const [loading, setLoading] = useState(true);
    const [filtro, setFiltro] = useState('TODOS');

    useEffect(() => {
        reportesService.misReportes()
            .then(res => {
                setReportes(res.data);
                res.data.forEach(r => {
                    const fn = r.tipo === 'PERDIDO'
                        ? coincidenciasService.porPerdido(r.id)
                        : coincidenciasService.porEncontrado(r.id);
                    fn.then(cRes => {
                        setCoincidencias(prev => ({ ...prev, [r.id]: cRes.data }));
                    }).catch(() => {});
                });
            })
            .catch(() => setReportes([]))
            .finally(() => setLoading(false));
    }, []);

    const handleEstado = async (id, estado) => {
        try {
            await reportesService.actualizarEstado(id, estado);
            setReportes(prev => prev.map(r => r.id === id ? { ...r, estado } : r));
        } catch {}
    };

    const filteredReportes = filtro === 'TODOS' ? reportes :
        filtro === 'PERDIDO' || filtro === 'ENCONTRADO' ? reportes.filter(r => r.tipo === filtro) :
        reportes.filter(r => r.estado === filtro);

    if (loading) return <div className="page-loading"><div className="spinner-border"></div></div>;

    const totalCoincidencias = Object.values(coincidencias).reduce((sum, arr) => sum + (arr?.length || 0), 0);

    return (
        <div className="container mt-4 mb-5">
            <div className="section-header mb-4">
                <div>
                    <h3 className="section-title">
                        <i className="bi bi-list-check me-2 text-primary"></i>
                        Mis Reportes
                    </h3>
                    <p className="text-muted mb-0">{reportes.length} reportes · {totalCoincidencias} coincidencias</p>
                </div>
                <Link to="/reportar" className="btn btn-primary">
                    <i className="bi bi-plus-circle me-1"></i> Nuevo Reporte
                </Link>
            </div>

            {/* Filters */}
            <div className="d-flex flex-wrap gap-2 mb-4">
                {['TODOS', 'PERDIDO', 'ENCONTRADO', 'ACTIVO', 'RESUELTO'].map(f => (
                    <button key={f}
                            className={`btn btn-sm ${filtro === f ? 'btn-primary' : 'btn-outline-secondary'}`}
                            onClick={() => setFiltro(f)}>
                        {f === 'TODOS' ? `Todos (${reportes.length})` :
                         f === 'PERDIDO' ? `🔴 Perdidos (${reportes.filter(r => r.tipo === 'PERDIDO').length})` :
                         f === 'ENCONTRADO' ? `🟢 Encontrados (${reportes.filter(r => r.tipo === 'ENCONTRADO').length})` :
                         f === 'ACTIVO' ? `Activos (${reportes.filter(r => r.estado === 'ACTIVO').length})` :
                         `✅ Resueltos (${reportes.filter(r => r.estado === 'RESUELTO').length})`}
                    </button>
                ))}
            </div>

            {reportes.length === 0 ? (
                <div className="empty-state">
                    <i className="bi bi-inbox"></i>
                    <h5>No tienes reportes aún</h5>
                    <p>Crea tu primer reporte para buscar o reportar una mascota</p>
                    <Link to="/reportar" className="btn btn-primary">
                        <i className="bi bi-plus-circle me-1"></i> Crear primer reporte
                    </Link>
                </div>
            ) : filteredReportes.length === 0 ? (
                <div className="text-center py-5">
                    <p className="text-muted">No hay reportes con este filtro</p>
                </div>
            ) : (
                filteredReportes.map(r => {
                    const isPerdido = r.tipo === 'PERDIDO';
                    const matches = coincidencias[r.id] || [];
                    const speciesEmoji = r.especie?.toLowerCase().includes('perro') ? '🐕' :
                                        r.especie?.toLowerCase().includes('gato') ? '🐈' : '🐾';
                    return (
                        <div key={r.id} className="card mb-3">
                            <div className="card-body">
                                <div className="row align-items-center">
                                    {/* Photo */}
                                    <div className="col-auto">
                                        <Link to={`/reporte/${r.id}`}>
                                            {r.fotoUrl ? (
                                                <img src={r.fotoUrl}
                                                     className="rounded"
                                                     style={{ width: '90px', height: '90px', objectFit: 'cover' }}
                                                     alt={r.nombre || r.especie} />
                                            ) : (
                                                <div className="rounded bg-light d-flex align-items-center justify-content-center"
                                                     style={{ width: '90px', height: '90px', fontSize: '2.5rem' }}>
                                                    {speciesEmoji}
                                                </div>
                                            )}
                                        </Link>
                                    </div>

                                    {/* Info */}
                                    <div className="col">
                                        <div className="d-flex align-items-center gap-2 mb-1">
                                            <span className={`badge ${isPerdido ? 'badge-perdido' : 'badge-encontrado'}`}>
                                                {r.tipo}
                                            </span>
                                            <span className={`badge badge-${r.estado?.toLowerCase() === 'activo' ? 'activo' : r.estado?.toLowerCase() === 'resuelto' ? 'resuelto' : 'inactivo'}`}>
                                                {r.estado}
                                            </span>
                                            {isPerdido && r.recompensa && (
                                                <span className="badge bg-warning text-dark">
                                                    💰 ${Number(r.recompensa).toLocaleString()}
                                                </span>
                                            )}
                                        </div>
                                        <Link to={`/reporte/${r.id}`} className="text-decoration-none">
                                            <h5 className="fw-bold text-dark mb-1">
                                                {r.nombre || r.especie} {r.raza && <span className="fw-normal text-muted">({r.raza})</span>}
                                            </h5>
                                        </Link>
                                        <div className="text-muted small mb-1">
                                            {r.color && <span className="me-2"><i className="bi bi-palette me-1"></i>{r.color}</span>}
                                            {r.tamano && <span className="me-2"><i className="bi bi-arrows me-1"></i>{formatTamano(r.tamano)}</span>}
                                            {r.direccion && <span><i className="bi bi-geo-alt me-1"></i>{r.direccion}</span>}
                                        </div>
                                        <small className="text-muted">
                                            <i className="bi bi-clock me-1"></i> {formatDate(r.createdAt)}
                                        </small>
                                    </div>

                                    {/* Actions */}
                                    <div className="col-auto text-end">
                                        <Link to={`/reporte/${r.id}`} className="btn btn-outline-primary btn-sm mb-1 d-block">
                                            <i className="bi bi-eye me-1"></i> Ver detalle
                                        </Link>
                                        {r.estado === 'ACTIVO' && (
                                            <button className="btn btn-success btn-sm d-block w-100"
                                                    onClick={() => handleEstado(r.id, 'RESUELTO')}>
                                                <i className="bi bi-check-circle me-1"></i> Resuelto
                                            </button>
                                        )}
                                    </div>
                                </div>

                                {/* Coincidencias inline */}
                                {matches.length > 0 && (
                                    <div className="mt-3 pt-3 border-top">
                                        <div className="d-flex align-items-center mb-2">
                                            <i className="bi bi-bell-fill text-warning me-2"></i>
                                            <strong className="text-warning small">
                                                {matches.length} coincidencia{matches.length > 1 ? 's' : ''} encontrada{matches.length > 1 ? 's' : ''}
                                            </strong>
                                        </div>
                                        <div className="d-flex flex-wrap gap-2">
                                            {matches.slice(0, 3).map(c => {
                                                const matchId = isPerdido ? c.reporteEncontradoId : c.reportePerdidoId;
                                                const scoreClass = c.scoreTotal >= 80 ? 'text-success' : c.scoreTotal >= 60 ? 'text-warning' : 'text-muted';
                                                return (
                                                    <Link key={c.id} to={`/reporte/${matchId}`}
                                                          className="card text-decoration-none border-warning" style={{ width: '180px' }}>
                                                        <div className="card-body py-2 px-3">
                                                            <div className={`fw-bold ${scoreClass}`}>
                                                                {c.scoreTotal.toFixed(0)}% match
                                                            </div>
                                                            <small className="text-muted">
                                                                {c.distanciaKm.toFixed(1)} km · {c.estado}
                                                            </small>
                                                        </div>
                                                    </Link>
                                                );
                                            })}
                                            {matches.length > 3 && (
                                                <Link to={`/reporte/${r.id}`} className="btn btn-outline-warning btn-sm align-self-center">
                                                    +{matches.length - 3} más
                                                </Link>
                                            )}
                                        </div>
                                    </div>
                                )}
                            </div>
                        </div>
                    );
                })
            )}
        </div>
    );
}
