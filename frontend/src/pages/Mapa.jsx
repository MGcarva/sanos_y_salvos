import { useState, useEffect } from 'react';
import { geoService } from '../services/services';
import ReporteMap from '../components/ReporteMap';

export default function Mapa() {
    const [puntos, setPuntos] = useState([]);
    const [filtro, setFiltro] = useState('');
    const [loading, setLoading] = useState(true);
    const [showClusters, setShowClusters] = useState(false);

    useEffect(() => {
        setLoading(true);
        const request = showClusters
            ? geoService.clusters()
            : geoService.heatmap(filtro || null);
        request
            .then(res => setPuntos(res.data))
            .catch(() => setPuntos([]))
            .finally(() => setLoading(false));
    }, [filtro, showClusters]);

    return (
        <div className="container-fluid px-3 mt-3 mb-4">
            <div className="card">
                <div className="card-header bg-white py-3">
                    <div className="d-flex justify-content-between align-items-center flex-wrap gap-2">
                        <h5 className="mb-0 fw-bold">
                            <i className="bi bi-map-fill text-primary me-2"></i>
                            Mapa de Reportes
                        </h5>
                        <div className="d-flex gap-2 flex-wrap">
                            <div className="btn-group">
                                <button className={`btn btn-sm ${filtro === '' ? 'btn-primary' : 'btn-outline-primary'}`}
                                        onClick={() => { setFiltro(''); setShowClusters(false); }}>
                                    <i className="bi bi-globe me-1"></i> Todos
                                </button>
                                <button className={`btn btn-sm ${filtro === 'PERDIDO' ? 'btn-danger' : 'btn-outline-danger'}`}
                                        onClick={() => { setFiltro('PERDIDO'); setShowClusters(false); }}>
                                    <i className="bi bi-search-heart me-1"></i> Perdidos
                                </button>
                                <button className={`btn btn-sm ${filtro === 'ENCONTRADO' ? 'btn-success' : 'btn-outline-success'}`}
                                        onClick={() => { setFiltro('ENCONTRADO'); setShowClusters(false); }}>
                                    <i className="bi bi-check-circle me-1"></i> Encontrados
                                </button>
                            </div>
                            <button className={`btn btn-sm ${showClusters ? 'btn-warning' : 'btn-outline-warning'}`}
                                    onClick={() => setShowClusters(!showClusters)}>
                                <i className="bi bi-bullseye me-1"></i> Clusters
                            </button>
                        </div>
                    </div>
                </div>
                <div className="card-body p-0">
                    {loading ? (
                        <div className="page-loading" style={{ height: '600px' }}>
                            <div className="spinner-border"></div>
                        </div>
                    ) : (
                        <ReporteMap reportes={puntos} zoom={6} height="600px" clickable />
                    )}
                </div>
                <div className="card-footer bg-white py-2">
                    <div className="d-flex justify-content-between align-items-center">
                        <small className="text-muted">
                            <span className="text-danger">●</span> Perdido &nbsp;
                            <span className="text-success">●</span> Encontrado &nbsp;
                            {showClusters && <><span className="text-warning">●</span> Cluster &nbsp;</>}
                        </small>
                        <small className="text-muted fw-bold">{puntos.length} reportes</small>
                    </div>
                </div>
            </div>
        </div>
    );
}
