import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import { dashboardService } from '../services/services';

export default function MascotasPerdidas() {
    const [reportes, setReportes] = useState([]);
    const [loading, setLoading] = useState(true);
    const [busqueda, setBusqueda] = useState('');

    useEffect(() => {
        dashboardService.get()
            .then(res => setReportes((res.data.reportes || []).filter(r => r.tipo === 'PERDIDO')))
            .catch(() => setReportes([]))
            .finally(() => setLoading(false));
    }, []);

    const filtrados = reportes.filter(r =>
        !busqueda ||
        r.nombre?.toLowerCase().includes(busqueda.toLowerCase()) ||
        r.especie?.toLowerCase().includes(busqueda.toLowerCase()) ||
        r.raza?.toLowerCase().includes(busqueda.toLowerCase()) ||
        r.direccion?.toLowerCase().includes(busqueda.toLowerCase())
    );

    const speciesEmoji = (especie) => {
        const e = especie?.toLowerCase() || '';
        if (e.includes('perro')) return '🐕';
        if (e.includes('gato')) return '🐈';
        if (e.includes('ave') || e.includes('pájaro') || e.includes('loro')) return '🐦';
        if (e.includes('conejo')) return '🐇';
        return '🐾';
    };

    return (
        <div className="container py-4">
            {/* Header */}
            <div className="d-flex align-items-center gap-3 mb-4">
                <Link to="/" className="btn btn-outline-secondary btn-sm">
                    <i className="bi bi-arrow-left me-1"></i>Volver
                </Link>
                <div>
                    <h3 className="fw-bold mb-0 text-danger">
                        <i className="bi bi-search-heart me-2"></i>Mascotas Perdidas
                    </h3>
                    <p className="text-muted mb-0">
                        {reportes.length} mascota{reportes.length !== 1 ? 's' : ''} reportada{reportes.length !== 1 ? 's' : ''} como perdida
                    </p>
                </div>
            </div>

            {/* Search */}
            <div className="mb-4">
                <div className="input-group">
                    <span className="input-group-text bg-white">
                        <i className="bi bi-search text-muted"></i>
                    </span>
                    <input
                        type="text"
                        className="form-control border-start-0"
                        placeholder="Buscar por nombre, especie, raza o lugar..."
                        value={busqueda}
                        onChange={e => setBusqueda(e.target.value)}
                    />
                    {busqueda && (
                        <button className="btn btn-outline-secondary" onClick={() => setBusqueda('')}>
                            <i className="bi bi-x"></i>
                        </button>
                    )}
                </div>
            </div>

            {loading ? (
                <div className="page-loading"><div className="spinner-border text-danger" role="status"></div></div>
            ) : filtrados.length === 0 ? (
                <div className="empty-state">
                    <i className="bi bi-inbox"></i>
                    <h5>{busqueda ? 'Sin resultados para tu búsqueda' : '¡No hay mascotas perdidas!'}</h5>
                    <p>{busqueda ? 'Prueba con otro término' : 'Buenas noticias para todos'}</p>
                    {busqueda && <button className="btn btn-outline-secondary mt-2" onClick={() => setBusqueda('')}>Limpiar búsqueda</button>}
                </div>
            ) : (
                <div className="row g-4">
                    {filtrados.map(reporte => (
                        <div key={reporte.id} className="col-md-4 col-lg-3">
                            <Link to={`/reporte/${reporte.id}`} className="text-decoration-none">
                                <div className="card card-reporte h-100">
                                    <div className="card-img-wrapper">
                                        {reporte.fotoUrl ? (
                                            <img
                                                src={reporte.fotoUrl}
                                                className="card-img-top"
                                                alt={reporte.nombre || reporte.especie}
                                            />
                                        ) : (
                                            <div className="card-img-placeholder">
                                                {speciesEmoji(reporte.especie)}
                                            </div>
                                        )}
                                        <span className="badge badge-perdido position-absolute" style={{ top: '12px', left: '12px' }}>
                                            <i className="bi bi-exclamation-triangle me-1"></i>PERDIDO
                                        </span>
                                    </div>
                                    <div className="card-body">
                                        <h6 className="fw-bold text-dark mb-1">
                                            {reporte.nombre || reporte.especie}
                                        </h6>
                                        <div className="text-muted small mb-2">
                                            {reporte.especie && <span className="me-2">{reporte.especie}</span>}
                                            {reporte.raza && <span className="me-2">· {reporte.raza}</span>}
                                            {reporte.color && <span>· {reporte.color}</span>}
                                        </div>
                                        {reporte.descripcion && (
                                            <p className="card-text text-muted small mb-2">
                                                {reporte.descripcion.substring(0, 70)}{reporte.descripcion.length > 70 ? '...' : ''}
                                            </p>
                                        )}
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
        </div>
    );
}
