import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
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

export default function ReporteMap({ reportes = [], center = [4.711, -74.0721], zoom = 12, height = '500px', clickable = false }) {
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
                        <Popup>
                            <div style={{ minWidth: '160px' }}>
                                <strong className={reporte.tipo === 'PERDIDO' ? 'text-danger' : 'text-success'}>
                                    {reporte.tipo === 'PERDIDO' ? '🔴' : '🟢'} {reporte.tipo}
                                </strong>
                                <br />
                                <span style={{ fontSize: '1.05em', fontWeight: 600 }}>
                                    {reporte.especie} {reporte.raza ? `- ${reporte.raza}` : ''}
                                </span>
                                <br />
                                {reporte.nombre && <><small>Nombre: {reporte.nombre}</small><br /></>}
                                {reporte.color && <><small>Color: {reporte.color}</small><br /></>}
                                {reporte.direccion && <small>📍 {reporte.direccion}</small>}
                                {clickable && id && (
                                    <div style={{ marginTop: '6px' }}>
                                        <Link to={`/reporte/${id}`}
                                              className="btn btn-primary btn-sm w-100"
                                              style={{ fontSize: '0.75rem' }}>
                                            Ver detalle →
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
