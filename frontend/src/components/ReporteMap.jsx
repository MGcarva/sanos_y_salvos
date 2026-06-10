import { MapContainer, TileLayer, Marker, Tooltip, Popup } from 'react-leaflet';
import { Link } from 'react-router-dom';
import 'leaflet/dist/leaflet.css';
import L from 'leaflet';

delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
    iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon-2x.png',
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png'
});

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

export default function ReporteMap({ reportes = [], center = [-33.6883, -71.2133], zoom = 12, height = '500px', clickable = false }) {
    return (
        <MapContainer center={center} zoom={zoom} style={{ height, width: '100%' }}>
            <TileLayer
                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            />
            {reportes.filter(r => r.lat && r.lng).map(reporte => {
                const id = reporte.reporteId || reporte.id;
                return (
                    <Marker
                        key={id}
                        position={[reporte.lat, reporte.lng]}
                        icon={reporte.tipo === 'PERDIDO' ? perdidoIcon : encontradoIcon}
                    >
                        <Tooltip direction="top" offset={[0, -36]} opacity={1}>
                            <div style={{ minWidth: '180px', maxWidth: '230px' }}>
                                {reporte.fotoUrl && (
                                    <img
                                        src={reporte.fotoUrl}
                                        alt="foto"
                                        style={{ width: '100%', height: '100px', objectFit: 'cover', borderRadius: '5px', marginBottom: '5px' }}
                                    />
                                )}
                                <div style={{ fontWeight: 700, color: reporte.tipo === 'PERDIDO' ? '#dc3545' : '#198754' }}>
                                    {reporte.tipo === 'PERDIDO' ? '🔴 PERDIDO' : '🟢 ENCONTRADO'}
                                </div>
                                <div style={{ fontWeight: 600 }}>
                                    {reporte.especie || ''}
                                    {reporte.raza ? ` · ${reporte.raza}` : ''}
                                    {reporte.tamano ? ` (${reporte.tamano.toLowerCase()})` : ''}
                                </div>
                                {reporte.nombre && <div>🐾 <b>{reporte.nombre}</b></div>}
                                {reporte.color && <div><small>Color: {reporte.color}</small></div>}
                                {reporte.direccion && <div><small>📍 {reporte.direccion}</small></div>}
                                {reporte.fechaEvento && (
                                    <div><small>📅 {new Date(reporte.fechaEvento).toLocaleDateString('es-CL')}</small></div>
                                )}
                                {reporte.tipo === 'PERDIDO' && reporte.recompensa > 0 && (
                                    <div><small>💰 Recompensa: ${Number(reporte.recompensa).toLocaleString('es-CL')}</small></div>
                                )}
                                {reporte.tipo === 'ENCONTRADO' && reporte.lugarResguardo && (
                                    <div><small>🏠 {reporte.lugarResguardo}</small></div>
                                )}
                                {reporte.descripcion && (
                                    <div><small style={{ color: '#555' }}>
                                        {reporte.descripcion.length > 70 ? reporte.descripcion.substring(0, 70) + '…' : reporte.descripcion}
                                    </small></div>
                                )}
                                {id && <div style={{ marginTop: '4px', color: '#0d6efd', fontSize: '0.8rem' }}>Haz clic para ver contacto →</div>}
                            </div>
                        </Tooltip>
                        <Popup>
                            <div style={{ minWidth: '180px' }}>
                                <strong style={{ color: reporte.tipo === 'PERDIDO' ? '#dc3545' : '#198754' }}>
                                    {reporte.tipo === 'PERDIDO' ? '🔴 PERDIDO' : '🟢 ENCONTRADO'}
                                </strong>
                                <div style={{ fontWeight: 600 }}>
                                    {reporte.especie}{reporte.raza ? ` · ${reporte.raza}` : ''}
                                </div>
                                {reporte.nombre && <div>🐾 <b>{reporte.nombre}</b></div>}
                                {id && (
                                    <div style={{ marginTop: '8px' }}>
                                        <Link to={`/reporte/${id}`} className="btn btn-primary btn-sm w-100" style={{ fontSize: '0.78rem' }}>
                                            Ver contacto y detalle →
                                        </Link>
                                    </div>
                                )}
                            </div>
                        </Popup>
                    </Marker>
                );
            })}
        </MapContainer>
    );
}
