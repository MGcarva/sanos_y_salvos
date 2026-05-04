import { useState, useRef, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { MapContainer, TileLayer, Marker, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { reportesService } from '../services/services';

const markerIcon = new L.Icon({
    iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-icon.png',
    shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/images/marker-shadow.png',
    iconSize: [25, 41], iconAnchor: [12, 41], popupAnchor: [1, -34], shadowSize: [41, 41]
});

function LocationPicker({ position, onPositionChange }) {
    useMapEvents({
        click(e) {
            onPositionChange(e.latlng.lat.toFixed(6), e.latlng.lng.toFixed(6));
        }
    });
    return position ? <Marker position={position} icon={markerIcon} /> : null;
}

const ESPECIES = [
    { value: 'Perro', icon: '🐕', label: 'Perro' },
    { value: 'Gato', icon: '🐈', label: 'Gato' },
    { value: 'Ave', icon: '🐦', label: 'Ave' },
    { value: 'Conejo', icon: '🐇', label: 'Conejo' },
    { value: 'Otro', icon: '🐾', label: 'Otro' }
];

const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/jpg'];

export default function Reportar() {
    const navigate = useNavigate();
    const fileInputRef = useRef(null);
    const [step, setStep] = useState(1);
    const [form, setForm] = useState({
        tipo: 'PERDIDO', especie: '', raza: '', nombre: '', color: '',
        tamano: 'MEDIANO', descripcion: '', lat: '', lng: '', direccion: '',
        fechaEvento: new Date().toISOString().split('T')[0],
        recompensa: '', lugarResguardo: '', tieneCollar: false
    });
    const [foto, setFoto] = useState(null);
    const [fotoPreview, setFotoPreview] = useState(null);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState(false);
    const [loading, setLoading] = useState(false);

    const handleChange = (e) => {
        const { name, value, type, checked } = e.target;
        setForm({ ...form, [name]: type === 'checkbox' ? checked : value });
    };

    const handleFileChange = (e) => {
        const file = e.target.files[0];
        if (!file) return;
        if (!ALLOWED_TYPES.includes(file.type)) {
            setError('Solo se permiten imágenes JPG o PNG');
            return;
        }
        if (file.size > MAX_FILE_SIZE) {
            setError('La imagen no puede superar 10MB');
            return;
        }
        setError('');
        setFoto(file);
        const reader = new FileReader();
        reader.onloadend = () => setFotoPreview(reader.result);
        reader.readAsDataURL(file);
    };

    const removePhoto = () => {
        setFoto(null);
        setFotoPreview(null);
        if (fileInputRef.current) fileInputRef.current.value = '';
    };

    const handlePositionChange = useCallback((lat, lng) => {
        setForm(prev => ({ ...prev, lat, lng }));
    }, []);

    const getLocation = () => {
        if (navigator.geolocation) {
            navigator.geolocation.getCurrentPosition(
                pos => {
                    setForm(prev => ({
                        ...prev,
                        lat: pos.coords.latitude.toFixed(6),
                        lng: pos.coords.longitude.toFixed(6)
                    }));
                },
                () => setError('No se pudo obtener la ubicación. Haz clic en el mapa.')
            );
        }
    };

    const validateStep1 = () => {
        if (!form.tipo) return 'Selecciona el tipo de reporte';
        if (!form.especie) return 'Selecciona la especie';
        if (!form.descripcion || form.descripcion.trim().length < 10) return 'La descripción debe tener al menos 10 caracteres';
        return null;
    };

    const validateStep2 = () => {
        if (!form.lat || !form.lng) return 'Indica la ubicación en el mapa o usa GPS';
        return null;
    };

    const nextStep = () => {
        if (step === 1) {
            const err = validateStep1();
            if (err) { setError(err); return; }
        }
        if (step === 2) {
            const err = validateStep2();
            if (err) { setError(err); return; }
        }
        setError('');
        setStep(s => s + 1);
    };

    const prevStep = () => {
        setError('');
        setStep(s => s - 1);
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        setError('');
        setLoading(true);
        try {
            const reporte = {
                ...form,
                fechaEvento: form.fechaEvento ? `${form.fechaEvento}T00:00:00` : null,
                lat: form.lat ? parseFloat(form.lat) : null,
                lng: form.lng ? parseFloat(form.lng) : null,
                recompensa: form.recompensa ? parseFloat(form.recompensa) : null
            };
            await reportesService.crear(reporte, foto);
            setSuccess(true);
            setTimeout(() => navigate('/mis-reportes'), 2000);
        } catch (err) {
            setError(err.response?.data?.message || 'Error al crear reporte');
        } finally {
            setLoading(false);
        }
    };

    const mapPosition = form.lat && form.lng ? [parseFloat(form.lat), parseFloat(form.lng)] : null;

    if (success) {
        return (
            <div className="container mt-5">
                <div className="text-center py-5">
                    <div className="rounded-circle bg-success bg-opacity-10 d-inline-flex align-items-center justify-content-center mb-3"
                         style={{ width: '100px', height: '100px' }}>
                        <i className="bi bi-check-lg text-success" style={{ fontSize: '3rem' }}></i>
                    </div>
                    <h3 className="fw-bold">¡Reporte creado exitosamente!</h3>
                    <p className="text-muted">Nuestro sistema buscará coincidencias automáticamente.</p>
                    <p className="text-muted">Redirigiendo a tus reportes...</p>
                </div>
            </div>
        );
    }

    return (
        <div className="container mt-4 mb-5">
            <div className="row justify-content-center">
                <div className="col-lg-8">
                    <h3 className="fw-bold mb-1">
                        <i className="bi bi-plus-circle-fill text-primary me-2"></i>
                        Nuevo Reporte
                    </h3>
                    <p className="text-muted mb-4">Completa la información para crear tu reporte</p>

                    {/* Step Indicator */}
                    <div className="step-indicator">
                        <div className={`step ${step >= 1 ? (step > 1 ? 'completed' : 'active') : ''}`}>
                            {step > 1 ? <i className="bi bi-check-lg"></i> : '1'}
                        </div>
                        <div className={`step-line ${step > 1 ? 'active' : ''}`}></div>
                        <div className={`step ${step >= 2 ? (step > 2 ? 'completed' : 'active') : ''}`}>
                            {step > 2 ? <i className="bi bi-check-lg"></i> : '2'}
                        </div>
                        <div className={`step-line ${step > 2 ? 'active' : ''}`}></div>
                        <div className={`step ${step >= 3 ? 'active' : ''}`}>3</div>
                    </div>

                    {error && (
                        <div className="alert alert-danger d-flex align-items-center">
                            <i className="bi bi-exclamation-triangle-fill me-2"></i>
                            {error}
                        </div>
                    )}

                    <div className="card shadow-sm">
                        <div className="card-body p-4">
                            <form onSubmit={handleSubmit}>

                                {/* STEP 1: Info de la mascota */}
                                {step === 1 && (
                                    <>
                                        <h5 className="fw-bold mb-3">
                                            <i className="bi bi-info-circle me-2 text-primary"></i>
                                            Información de la mascota
                                        </h5>

                                        {/* Tipo de reporte */}
                                        <div className="mb-4">
                                            <label className="form-label">Tipo de reporte *</label>
                                            <div className="type-toggle">
                                                <div className={`type-option ${form.tipo === 'PERDIDO' ? 'active-perdido' : ''}`}
                                                     onClick={() => setForm({ ...form, tipo: 'PERDIDO' })}>
                                                    <i className="bi bi-search-heart"></i>
                                                    <span>Mascota Perdida</span>
                                                </div>
                                                <div className={`type-option ${form.tipo === 'ENCONTRADO' ? 'active-encontrado' : ''}`}
                                                     onClick={() => setForm({ ...form, tipo: 'ENCONTRADO' })}>
                                                    <i className="bi bi-emoji-smile"></i>
                                                    <span>Mascota Encontrada</span>
                                                </div>
                                            </div>
                                        </div>

                                        {/* Especie */}
                                        <div className="mb-3">
                                            <label className="form-label">Especie *</label>
                                            <div className="d-flex flex-wrap gap-2">
                                                {ESPECIES.map(esp => (
                                                    <button key={esp.value} type="button"
                                                            className={`btn ${form.especie === esp.value ? 'btn-primary' : 'btn-outline-secondary'} px-3`}
                                                            onClick={() => setForm({ ...form, especie: esp.value })}>
                                                        {esp.icon} {esp.label}
                                                    </button>
                                                ))}
                                            </div>
                                        </div>

                                        <div className="row">
                                            <div className="col-md-6 mb-3">
                                                <label className="form-label">Nombre de la mascota</label>
                                                <input type="text" name="nombre" className="form-control"
                                                       placeholder="Ej: Max, Luna"
                                                       value={form.nombre} onChange={handleChange} />
                                            </div>
                                            <div className="col-md-6 mb-3">
                                                <label className="form-label">Raza</label>
                                                <input type="text" name="raza" className="form-control"
                                                       placeholder="Ej: Labrador, Siamés, Criollo"
                                                       value={form.raza} onChange={handleChange} />
                                            </div>
                                        </div>

                                        <div className="row">
                                            <div className="col-md-6 mb-3">
                                                <label className="form-label">Color</label>
                                                <input type="text" name="color" className="form-control"
                                                       placeholder="Ej: Negro, Blanco con manchas"
                                                       value={form.color} onChange={handleChange} />
                                            </div>
                                            <div className="col-md-6 mb-3">
                                                <label className="form-label">Tamaño</label>
                                                <select name="tamano" className="form-select" value={form.tamano} onChange={handleChange}>
                                                    <option value="PEQUENO">🐕 Pequeño (menos de 10 kg)</option>
                                                    <option value="MEDIANO">🐕 Mediano (10-25 kg)</option>
                                                    <option value="GRANDE">🐕 Grande (más de 25 kg)</option>
                                                </select>
                                            </div>
                                        </div>

                                        <div className="mb-3">
                                            <label className="form-label">Descripción detallada *</label>
                                            <textarea name="descripcion" className="form-control" rows="4"
                                                      placeholder="Describe la mascota: señas particulares, comportamiento, collar, chip, etc."
                                                      value={form.descripcion} onChange={handleChange} required />
                                            <small className="text-muted">{form.descripcion.length}/500 caracteres</small>
                                        </div>

                                        <div className="mb-3">
                                            <label className="form-label">
                                                <i className="bi bi-calendar me-1"></i> Fecha del evento
                                            </label>
                                            <input type="date" name="fechaEvento" className="form-control"
                                                   value={form.fechaEvento} onChange={handleChange}
                                                   max={new Date().toISOString().split('T')[0]} />
                                        </div>

                                        {/* Campos condicionales */}
                                        {form.tipo === 'PERDIDO' && (
                                            <div className="mb-3 p-3 bg-danger bg-opacity-10 rounded-3">
                                                <label className="form-label fw-bold text-danger">
                                                    <i className="bi bi-cash me-1"></i> Recompensa (opcional)
                                                </label>
                                                <div className="input-group">
                                                    <span className="input-group-text">$</span>
                                                    <input type="number" name="recompensa" className="form-control"
                                                           placeholder="0"
                                                           value={form.recompensa} onChange={handleChange} min="0" />
                                                    <span className="input-group-text">COP</span>
                                                </div>
                                            </div>
                                        )}
                                        {form.tipo === 'ENCONTRADO' && (
                                            <div className="p-3 bg-success bg-opacity-10 rounded-3 mb-3">
                                                <div className="mb-3">
                                                    <label className="form-label fw-bold text-success">
                                                        <i className="bi bi-house me-1"></i> Lugar de resguardo
                                                    </label>
                                                    <input type="text" name="lugarResguardo" className="form-control"
                                                           placeholder="¿Dónde está la mascota ahora?"
                                                           value={form.lugarResguardo} onChange={handleChange} />
                                                </div>
                                                <div className="form-check">
                                                    <input type="checkbox" name="tieneCollar" className="form-check-input"
                                                           id="tieneCollar"
                                                           checked={form.tieneCollar} onChange={handleChange} />
                                                    <label className="form-check-label fw-bold text-success" htmlFor="tieneCollar">
                                                        <i className="bi bi-tag me-1"></i> Tiene collar
                                                    </label>
                                                </div>
                                            </div>
                                        )}

                                        <div className="d-flex justify-content-end mt-4">
                                            <button type="button" className="btn btn-primary btn-lg px-4" onClick={nextStep}>
                                                Siguiente <i className="bi bi-arrow-right ms-2"></i>
                                            </button>
                                        </div>
                                    </>
                                )}

                                {/* STEP 2: Ubicación */}
                                {step === 2 && (
                                    <>
                                        <h5 className="fw-bold mb-3">
                                            <i className="bi bi-geo-alt me-2 text-primary"></i>
                                            Ubicación
                                        </h5>
                                        <p className="text-muted small mb-3">
                                            Haz clic en el mapa para seleccionar la ubicación, o usa el botón GPS.
                                        </p>

                                        <div className="mb-3">
                                            <div className="d-flex gap-2 mb-2">
                                                <button type="button" className="btn btn-outline-primary btn-sm" onClick={getLocation}>
                                                    <i className="bi bi-crosshair me-1"></i> Usar mi ubicación (GPS)
                                                </button>
                                                {mapPosition && (
                                                    <span className="badge bg-success align-self-center">
                                                        <i className="bi bi-check-circle me-1"></i>
                                                        {form.lat}, {form.lng}
                                                    </span>
                                                )}
                                            </div>
                                            <div className="map-container" style={{ height: '350px' }}>
                                                <MapContainer
                                                    center={mapPosition || [4.711, -74.0721]}
                                                    zoom={mapPosition ? 15 : 12}
                                                    style={{ height: '100%', width: '100%' }}
                                                >
                                                    <TileLayer
                                                        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                                                        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                                    />
                                                    <LocationPicker
                                                        position={mapPosition}
                                                        onPositionChange={handlePositionChange}
                                                    />
                                                </MapContainer>
                                            </div>
                                        </div>

                                        <div className="mb-3">
                                            <label className="form-label">
                                                <i className="bi bi-signpost me-1"></i> Dirección de referencia
                                            </label>
                                            <input type="text" name="direccion" className="form-control"
                                                   placeholder="Ej: Calle 100 con Carrera 15, cerca al parque..."
                                                   value={form.direccion} onChange={handleChange} />
                                        </div>

                                        <div className="d-flex justify-content-between mt-4">
                                            <button type="button" className="btn btn-outline-secondary btn-lg px-4" onClick={prevStep}>
                                                <i className="bi bi-arrow-left me-2"></i> Atrás
                                            </button>
                                            <button type="button" className="btn btn-primary btn-lg px-4" onClick={nextStep}>
                                                Siguiente <i className="bi bi-arrow-right ms-2"></i>
                                            </button>
                                        </div>
                                    </>
                                )}

                                {/* STEP 3: Foto y confirmación */}
                                {step === 3 && (
                                    <>
                                        <h5 className="fw-bold mb-3">
                                            <i className="bi bi-camera me-2 text-primary"></i>
                                            Foto y confirmación
                                        </h5>

                                        <div className="mb-4">
                                            <label className="form-label">Foto de la mascota</label>
                                            <div className={`image-upload-area ${fotoPreview ? 'has-image' : ''}`}
                                                 onClick={() => !fotoPreview && fileInputRef.current?.click()}>
                                                {fotoPreview ? (
                                                    <>
                                                        <img src={fotoPreview} className="preview-img" alt="Preview" />
                                                        <button type="button" className="btn btn-danger btn-sm remove-btn"
                                                                onClick={(e) => { e.stopPropagation(); removePhoto(); }}>
                                                            <i className="bi bi-x-lg"></i>
                                                        </button>
                                                    </>
                                                ) : (
                                                    <>
                                                        <i className="bi bi-cloud-arrow-up text-muted" style={{ fontSize: '2.5rem' }}></i>
                                                        <div className="mt-2 fw-bold">Haz clic para subir una foto</div>
                                                        <small className="text-muted">JPG o PNG · Máximo 10 MB</small>
                                                    </>
                                                )}
                                            </div>
                                            <input ref={fileInputRef} type="file" className="d-none"
                                                   accept="image/jpeg,image/png,image/jpg"
                                                   onChange={handleFileChange} />
                                        </div>

                                        {/* Resumen */}
                                        <div className="card bg-light mb-4">
                                            <div className="card-body">
                                                <h6 className="fw-bold mb-3">
                                                    <i className="bi bi-clipboard-check me-2"></i> Resumen del reporte
                                                </h6>
                                                <div className="row g-2">
                                                    <div className="col-6">
                                                        <small className="text-muted d-block">Tipo</small>
                                                        <span className={`badge ${form.tipo === 'PERDIDO' ? 'badge-perdido' : 'badge-encontrado'}`}>
                                                            {form.tipo}
                                                        </span>
                                                    </div>
                                                    <div className="col-6">
                                                        <small className="text-muted d-block">Especie</small>
                                                        <strong>{form.especie}</strong>
                                                    </div>
                                                    {form.nombre && (
                                                        <div className="col-6">
                                                            <small className="text-muted d-block">Nombre</small>
                                                            <strong>{form.nombre}</strong>
                                                        </div>
                                                    )}
                                                    {form.raza && (
                                                        <div className="col-6">
                                                            <small className="text-muted d-block">Raza</small>
                                                            <strong>{form.raza}</strong>
                                                        </div>
                                                    )}
                                                    {form.color && (
                                                        <div className="col-6">
                                                            <small className="text-muted d-block">Color</small>
                                                            <strong>{form.color}</strong>
                                                        </div>
                                                    )}
                                                    <div className="col-6">
                                                        <small className="text-muted d-block">Tamaño</small>
                                                        <strong>{form.tamano === 'PEQUENO' ? 'Pequeño' : form.tamano === 'MEDIANO' ? 'Mediano' : 'Grande'}</strong>
                                                    </div>
                                                    <div className="col-12">
                                                        <small className="text-muted d-block">Ubicación</small>
                                                        <strong>
                                                            <i className="bi bi-geo-alt me-1"></i>
                                                            {form.direccion || `${form.lat}, ${form.lng}`}
                                                        </strong>
                                                    </div>
                                                    <div className="col-12">
                                                        <small className="text-muted d-block">Descripción</small>
                                                        <span>{form.descripcion}</span>
                                                    </div>
                                                    {form.recompensa && (
                                                        <div className="col-12">
                                                            <small className="text-muted d-block">Recompensa</small>
                                                            <strong className="text-success">${Number(form.recompensa).toLocaleString()} COP</strong>
                                                        </div>
                                                    )}
                                                </div>
                                            </div>
                                        </div>

                                        <div className="d-flex justify-content-between">
                                            <button type="button" className="btn btn-outline-secondary btn-lg px-4" onClick={prevStep}>
                                                <i className="bi bi-arrow-left me-2"></i> Atrás
                                            </button>
                                            <button type="submit" className="btn btn-primary btn-lg px-5" disabled={loading}>
                                                {loading ? (
                                                    <><span className="spinner-border spinner-border-sm me-2"></span>Enviando...</>
                                                ) : (
                                                    <><i className="bi bi-send me-2"></i>Crear Reporte</>
                                                )}
                                            </button>
                                        </div>
                                    </>
                                )}
                            </form>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
}
