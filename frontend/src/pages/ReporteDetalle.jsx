import { useState, useEffect } from 'react';
import { useParams, Link } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { reportesService, coincidenciasService } from '../services/services';
import { useAuth } from '../contexts/AuthContext';

const perdidoIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-red.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
    iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41]
});

const encontradoIcon = new L.Icon({
    iconUrl: 'https://raw.githubusercontent.com/pointhi/leaflet-color-markers/master/img/marker-icon-2x-green.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
    iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41]
});

function formatDate(dateStr) {
    if (!dateStr) return '';
    return new Date(dateStr).toLocaleDateString('es-CO', {
        year: 'numeric', month: 'long', day: 'numeric'
    });
}

function formatTamano(t) {
    if (t === 'PEQUENO') return 'Pequeño';
    if (t === 'MEDIANO') return 'Mediano';
    if (t === 'GRANDE') return 'Grande';
    return t;
}

export default function ReporteDetalle() {
    const { id } = useParams();
    const { user } = useAuth();
    const [reporte, setReporte] = useState(null);
    const [coincidencias, setCoincidencias] = useState([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState('');

    useEffect(() => {
        setLoading(true);
        reportesService.obtenerPorId(id)
            .then(res => {
                setReporte(res.data);
                const fn = res.data.tipo === 'PERDIDO'
                    ? coincidenciasService.porPerdido(id)
                    : coincidenciasService.porEncontrado(id);
                return fn.catch(() => ({ data: [] }));
            })
            .then(res => setCoincidencias(res.data || []))
            .catch(() => setError('No se pudo cargar el reporte'))
            .finally(() => setLoading(false));
    }, [id]);

    if (loading) {
        return <div className="page-loading"><div className="spinner-border"></div></div>;
    }

    if (error || !reporte) {
        return (
            <div className="container mt-5">
                <div className="empty-state">
                    <i className="bi bi-exclamation-circle"></i>
                    <h5>{error || 'Reporte no encontrado'}</h5>
                    <Link to="/" className="btn btn-primary mt-3">Volver al inicio</Link>
                </div>
            </div>
        );
    }

    const isPerdido = reporte.tipo === 'PERDIDO';
    const isOwner = user?.userId === reporte.userId;
    const speciesEmoji = reporte.especie?.toLowerCase().includes('perro') ? '🐕' :
                         reporte.especie?.toLowerCase().includes('gato') ? '🐈' :
                         reporte.especie?.toLowerCase().includes('ave') ? '🐦' : '🐾';

    return (
        <div className="container mt-4 mb-5">
            <nav aria-label="breadcrumb" className="mb-3">
                <ol className="breadcrumb">
                    <li className="breadcrumb-item"><Link to="/">Inicio</Link></li>
                    <li className="breadcrumb-item"><Link to="/mapa">Mapa</Link></li>
                    <li className="breadcrumb-item active">{reporte.nombre || reporte.especie}</li>
                </ol>
            </nav>

            <div className="row g-4">
                {/* Left: Photo + Map */}
                <div className="col-lg-7">
                    {/* Photo */}
                    <div className="card mb-4">
                        {reporte.fotoUrl ? (
                            <img src={reporte.fotoUrl} className="detail-photo" alt={reporte.nombre || reporte.especie} />
                        ) : (
                            <div className="card-img-placeholder" style={{ height: '350px', fontSize: '6rem' }}>
                                {speciesEmoji}
                            </div>
                        )}
                        <div className="position-absolute" style={{ top: '16px', left: '16px' }}>
                            <span className={`badge ${isPerdido ? 'badge-perdido' : 'badge-encontrado'} fs-6`}>
                                <i className={`bi ${isPerdido ? 'bi-exclamation-triangle' : 'bi-check-circle'} me-1`}></i>
                                {reporte.tipo}
                            </span>
                        </div>
                    </div>

                    {/* Map */}
                    {reporte.lat && reporte.lng && (
                        <div className="card">
                            <div className="card-header bg-white py-3">
                                <h6 className="mb-0 fw-bold">
                                    <i className="bi bi-geo-alt-fill text-primary me-2"></i>
                                    Ubicación del reporte
                                </h6>
                            </div>
                            <div className="card-body p-0">
                                <div style={{ height: '300px' }}>
                                    <MapContainer
                                        center={[reporte.lat, reporte.lng]}
                                        zoom={15}
                                        style={{ height: '100%', width: '100%' }}
                                    >
                                        <TileLayer
                                            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                                            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                        />
                                        <Marker
                                            position={[reporte.lat, reporte.lng]}
                                            icon={isPerdido ? perdidoIcon : encontradoIcon}
                                        >
                                            <Popup>
                                                <strong>{reporte.tipo}</strong><br />
                                                {reporte.direccion || `${reporte.lat}, ${reporte.lng}`}
                                            </Popup>
                                        </Marker>
                                    </MapContainer>
                                </div>
                            </div>
                        </div>
                    )}
                </div>

                {/* Right: Details */}
                <div className="col-lg-5">
                    <div className="card mb-4">
                        <div className="card-body">
                            <div className="d-flex justify-content-between align-items-start mb-3">
                                <div>
                                    <h3 className="fw-bold mb-1">{reporte.nombre || reporte.especie}</h3>
                                    {reporte.nombre && <span className="text-muted">{reporte.especie}</span>}
                                </div>
                                <span className={`badge badge-${reporte.estado?.toLowerCase() === 'activo' ? 'activo' : reporte.estado?.toLowerCase() === 'resuelto' ? 'resuelto' : 'inactivo'}`}>
                                    {reporte.estado}
                                </span>
                            </div>

                            <dl className="detail-info">
                                {reporte.raza && (
                                    <><dt><i className="bi bi-tag me-1"></i> Raza</dt><dd>{reporte.raza}</dd></>
                                )}
                                {reporte.color && (
                                    <><dt><i className="bi bi-palette me-1"></i> Color</dt><dd>{reporte.color}</dd></>
                                )}
                                {reporte.tamano && (
                                    <><dt><i className="bi bi-arrows me-1"></i> Tamaño</dt><dd>{formatTamano(reporte.tamano)}</dd></>
                                )}
                                <dt><i className="bi bi-text-paragraph me-1"></i> Descripción</dt>
                                <dd>{reporte.descripcion}</dd>
                                {reporte.direccion && (
                                    <><dt><i className="bi bi-geo-alt me-1"></i> Dirección</dt><dd>{reporte.direccion}</dd></>
                                )}
                                {reporte.fechaEvento && (
                                    <><dt><i className="bi bi-calendar-event me-1"></i> Fecha del evento</dt><dd>{formatDate(reporte.fechaEvento)}</dd></>
                                )}
                                <dt><i className="bi bi-clock me-1"></i> Publicado</dt>
                                <dd>{formatDate(reporte.createdAt)}</dd>

                                {isPerdido && reporte.recompensa && (
                                    <>
                                        <dt><i className="bi bi-cash me-1"></i> Recompensa</dt>
                                        <dd>
                                            <span className="badge bg-success fs-6 px-3 py-2">
                                                ${Number(reporte.recompensa).toLocaleString()} COP
                                            </span>
                                        </dd>
                                    </>
                                )}
                                {!isPerdido && reporte.lugarResguardo && (
                                    <><dt><i className="bi bi-house me-1"></i> Lugar de resguardo</dt><dd>{reporte.lugarResguardo}</dd></>
                                )}
                                {!isPerdido && reporte.tieneCollar && (
                                    <><dt><i className="bi bi-tag me-1"></i> Collar</dt><dd><span className="badge bg-info">Tiene collar</span></dd></>
                                )}
                            </dl>
                        </div>
                    </div>

                    {/* Coincidencias */}
                    {coincidencias.length > 0 && (
                        <div className="card">
                            <div className="card-header bg-white py-3">
                                <h6 className="mb-0 fw-bold">
                                    <i className="bi bi-link-45deg text-warning me-2"></i>
                                    Coincidencias ({coincidencias.length})
                                </h6>
                            </div>
                            <div className="card-body">
                                {coincidencias.map(c => {
                                    const matchId = isPerdido ? c.reporteEncontradoId : c.reportePerdidoId;
                                    const scoreClass = c.scoreTotal >= 80 ? 'score-high' : c.scoreTotal >= 60 ? 'score-medium' : 'score-low';
                                    return (
                                        <div key={c.id} className="coincidencia-card card mb-2">
                                            <div className="card-body py-3">
                                                <div className="d-flex align-items-center gap-3">
                                                    <div className={`score-badge ${scoreClass}`}>
                                                        {Math.round(c.scoreTotal)}
                                                    </div>
                                                    <div className="flex-grow-1">
                                                        <div className="fw-bold small">
                                                            Score: {c.scoreTotal.toFixed(1)}%
                                                        </div>
                                                        <div className="text-muted small">
                                                            <i className="bi bi-geo me-1"></i>
                                                            {c.distanciaKm.toFixed(1)} km de distancia
                                                        </div>
                                                        <div className="small mt-1">
                                                            <span className="me-2">Raza: {c.scoreRaza?.toFixed(0) || 0}</span>
                                                            <span className="me-2">Tamaño: {c.scoreTamano?.toFixed(0) || 0}</span>
                                                            <span>Color: {c.scoreColor?.toFixed(0) || 0}</span>
                                                        </div>
                                                    </div>
                                                    <div>
                                                        <span className={`badge ${c.estado === 'CONFIRMADA' ? 'bg-success' : c.estado === 'DESCARTADA' ? 'bg-secondary' : 'bg-warning text-dark'} mb-1 d-block`}>
                                                            {c.estado}
                                                        </span>
                                                        <Link to={`/reporte/${matchId}`}
                                                              className="btn btn-outline-primary btn-sm w-100">
                                                            <i className="bi bi-eye me-1"></i> Ver
                                                        </Link>
                                                    </div>
                                                </div>
                                            </div>
                                        </div>
                                    );
                                })}
                            </div>
                        </div>
                    )}

                    {/* Actions */}
                    {isOwner && (
                        <div className="card mt-3">
                            <div className="card-body">
                                <h6 className="fw-bold mb-3">
                                    <i className="bi bi-gear me-2"></i> Acciones
                                </h6>
                                <div className="d-flex gap-2">
                                    {reporte.estado === 'ACTIVO' && (
                                        <button className="btn btn-success btn-sm flex-fill"
                                                onClick={async () => {
                                                    try {
                                                        await reportesService.actualizarEstado(id, 'RESUELTO');
                                                        setReporte({ ...reporte, estado: 'RESUELTO' });
                                                    } catch {}
                                                }}>
                                            <i className="bi bi-check-circle me-1"></i> Marcar resuelto
                                        </button>
                                    )}
                                    {reporte.estado === 'ACTIVO' && (
                                        <button className="btn btn-outline-secondary btn-sm flex-fill"
                                                onClick={async () => {
                                                    try {
                                                        await reportesService.actualizarEstado(id, 'INACTIVO');
                                                        setReporte({ ...reporte, estado: 'INACTIVO' });
                                                    } catch {}
                                                }}>
                                            <i className="bi bi-pause-circle me-1"></i> Desactivar
                                        </button>
                                    )}
                                    {reporte.estado === 'INACTIVO' && (
                                        <button className="btn btn-primary btn-sm flex-fill"
                                                onClick={async () => {
                                                    try {
                                                        await reportesService.actualizarEstado(id, 'ACTIVO');
                                                        setReporte({ ...reporte, estado: 'ACTIVO' });
                                                    } catch {}
                                                }}>
                                            <i className="bi bi-play-circle me-1"></i> Reactivar
                                        </button>
                                    )}
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
}
