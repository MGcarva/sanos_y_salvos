import { describe, it, expect, vi } from 'vitest';

// Mock api module
vi.mock('../services/api', () => ({
    default: {
        get: vi.fn(),
        post: vi.fn(),
        patch: vi.fn()
    }
}));

import api from '../services/api';
import {
    authService,
    reportesService,
    geoService,
    coincidenciasService,
    dashboardService
} from '../services/services';

describe('Services', () => {
    beforeEach(() => {
        vi.clearAllMocks();
    });

    describe('authService', () => {
        it('login calls POST /auth/login', async () => {
            const data = { email: 'test@test.com', password: '12345678' };
            api.post.mockResolvedValue({ data: { accessToken: 'token' } });

            await authService.login(data);

            expect(api.post).toHaveBeenCalledWith('/auth/login', data);
        });

        it('register calls POST /auth/register', async () => {
            const data = { nombre: 'Test', email: 'test@test.com', password: '12345678' };
            api.post.mockResolvedValue({ data: { accessToken: 'token' } });

            await authService.register(data);

            expect(api.post).toHaveBeenCalledWith('/auth/register', data);
        });

        it('refresh calls POST /auth/refresh', async () => {
            api.post.mockResolvedValue({ data: { accessToken: 'new-token' } });

            await authService.refresh('old-refresh-token');

            expect(api.post).toHaveBeenCalledWith('/auth/refresh', { refreshToken: 'old-refresh-token' });
        });

        it('verifyEmail calls GET /auth/verify-email', async () => {
            api.get.mockResolvedValue({ data: { message: 'ok' } });

            await authService.verifyEmail('token123');

            expect(api.get).toHaveBeenCalledWith('/auth/verify-email?token=token123');
        });
    });

    describe('reportesService', () => {
        it('listarActivos calls GET /reportes', async () => {
            api.get.mockResolvedValue({ data: [] });

            await reportesService.listarActivos();

            expect(api.get).toHaveBeenCalledWith('/reportes');
        });

        it('obtenerPorId calls GET /reportes/:id', async () => {
            api.get.mockResolvedValue({ data: {} });

            await reportesService.obtenerPorId('abc-123');

            expect(api.get).toHaveBeenCalledWith('/reportes/abc-123');
        });

        it('misReportes calls GET /reportes/mis-reportes', async () => {
            api.get.mockResolvedValue({ data: [] });

            await reportesService.misReportes();

            expect(api.get).toHaveBeenCalledWith('/reportes/mis-reportes');
        });

        it('crear sends multipart form data', async () => {
            const reporte = { tipo: 'PERDIDO', especie: 'Perro' };
            const foto = new File([''], 'test.jpg', { type: 'image/jpeg' });
            api.post.mockResolvedValue({ data: {} });

            await reportesService.crear(reporte, foto);

            expect(api.post).toHaveBeenCalledWith(
                '/reportes',
                expect.any(FormData),
                expect.objectContaining({
                    headers: { 'Content-Type': undefined }
                })
            );
        });
    });

    describe('geoService', () => {
        it('heatmap calls GET /geo/heatmap', async () => {
            api.get.mockResolvedValue({ data: [] });

            await geoService.heatmap();

            expect(api.get).toHaveBeenCalledWith('/geo/heatmap');
        });

        it('heatmap with tipo adds query param', async () => {
            api.get.mockResolvedValue({ data: [] });

            await geoService.heatmap('PERDIDO');

            expect(api.get).toHaveBeenCalledWith('/geo/heatmap?tipo=PERDIDO');
        });

        it('nearby calls with correct params', async () => {
            api.get.mockResolvedValue({ data: [] });

            await geoService.nearby(4.711, -74.072, 3000);

            expect(api.get).toHaveBeenCalledWith('/geo/nearby?lat=4.711&lng=-74.072&radiusMeters=3000');
        });

        it('clusters calls GET /geo/clusters', async () => {
            api.get.mockResolvedValue({ data: [] });

            await geoService.clusters();

            expect(api.get).toHaveBeenCalledWith('/geo/clusters');
        });
    });

    describe('coincidenciasService', () => {
        it('porPerdido calls correct endpoint', async () => {
            api.get.mockResolvedValue({ data: [] });

            await coincidenciasService.porPerdido('id-123');

            expect(api.get).toHaveBeenCalledWith('/coincidencias/perdido/id-123');
        });

        it('porEncontrado calls correct endpoint', async () => {
            api.get.mockResolvedValue({ data: [] });

            await coincidenciasService.porEncontrado('id-456');

            expect(api.get).toHaveBeenCalledWith('/coincidencias/encontrado/id-456');
        });
    });

    describe('dashboardService', () => {
        it('get calls GET /dashboard', async () => {
            api.get.mockResolvedValue({ data: {} });

            await dashboardService.get();

            expect(api.get).toHaveBeenCalledWith('/dashboard');
        });
    });
});
