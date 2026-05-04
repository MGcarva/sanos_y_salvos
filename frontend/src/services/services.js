import api from './api';

export const authService = {
    register: (data) => api.post('/auth/register', data),
    login: (data) => api.post('/auth/login', data),
    refresh: (refreshToken) => api.post('/auth/refresh', { refreshToken }),
    verifyEmail: (token) => api.get(`/auth/verify-email?token=${token}`)
};

export const reportesService = {
    listarActivos: () => api.get('/reportes'),
    obtenerPorId: (id) => api.get(`/reportes/${id}`),
    misReportes: () => api.get('/reportes/mis-reportes'),
    crear: (reporte, foto) => {
        const formData = new FormData();
        formData.append('reporte', new Blob([JSON.stringify(reporte)], { type: 'application/json' }));
        if (foto) formData.append('foto', foto);
        // No fijar Content-Type manualmente: axios detecta FormData y agrega el boundary correcto
        return api.post('/reportes', formData, {
            headers: { 'Content-Type': undefined }
        });
    },
    actualizarEstado: (id, estado) => api.patch(`/reportes/${id}/estado`, null, { params: { estado } })
};

export const geoService = {
    heatmap: (tipo) => api.get('/geo/heatmap' + (tipo ? `?tipo=${tipo}` : '')),
    nearby: (lat, lng, radius = 5000) => api.get(`/geo/nearby?lat=${lat}&lng=${lng}&radiusMeters=${radius}`),
    clusters: () => api.get('/geo/clusters')
};

export const coincidenciasService = {
    porPerdido: (id) => api.get(`/coincidencias/perdido/${id}`),
    porEncontrado: (id) => api.get(`/coincidencias/encontrado/${id}`),
    actualizarEstado: (id, estado) => api.patch(`/coincidencias/${id}/estado`, null, { params: { estado } })
};

export const dashboardService = {
    get: () => api.get('/dashboard')
};
